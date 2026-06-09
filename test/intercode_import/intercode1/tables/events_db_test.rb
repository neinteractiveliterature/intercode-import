# frozen_string_literal: true

require 'test_helper'

class EventsDbTest < Minitest::Test
  include DbTestHelper

  def self.setup_db(db)
    db.create_table!(:Events) do
      Integer :EventId, primary_key: true
      String  :Title
      String  :GameType
      Integer :Hours, default: 4
      Text    :Description
      Text    :ShortBlurb
      Text    :PlayerCommunications
      String  :Author
      String  :GameEMail
      String  :Organization
      String  :Homepage
      String  :CanPlayConcurrently, size: 1, default: 'N'
      String  :ConMailDest
      Integer :MaxPlayersMale,    default: 0
      Integer :MinPlayersMale,    default: 0
      Integer :PrefPlayersMale,   default: 0
      Integer :MaxPlayersFemale,  default: 0
      Integer :MinPlayersFemale,  default: 0
      Integer :PrefPlayersFemale, default: 0
      Integer :MaxPlayersNeutral,  default: 0
      Integer :MinPlayersNeutral,  default: 0
      Integer :PrefPlayersNeutral, default: 0
      String  :IsOps,     size: 1, default: 'N'
      String  :IsConSuite, size: 1, default: 'N'
      Integer :SpecialEvent, default: 0
    end
    db.create_table!(:Bids) do
      Integer :BidId, primary_key: true
      Integer :EventId
      String  :Status
    end
  end

  def self.teardown_db(db)
    db.drop_table?(:Bids, :Events)
  end

  def truncate_tables(db)
    db[:Bids].delete
    db[:Events].delete
  end

  def insert_event(overrides = {})
    defaults = {
      EventId: 1, Title: 'Test LARP', GameType: 'LARP', Hours: 4,
      IsOps: 'N', IsConSuite: 'N', SpecialEvent: 0,
      MaxPlayersMale: 3, MinPlayersMale: 1, PrefPlayersMale: 2,
      MaxPlayersFemale: 3, MinPlayersFemale: 1, PrefPlayersFemale: 2,
      MaxPlayersNeutral: 2, MinPlayersNeutral: 0, PrefPlayersNeutral: 1
    }
    @db[:Events].insert(defaults.merge(overrides))
  end

  def insert_bid(event_id:, status:, bid_id: 1)
    @db[:Bids].insert(BidId: bid_id, EventId: event_id, Status: status)
  end

  def export
    IntercodeImport::Intercode1::Tables::Events.new(@db).export!
  end

  # --- inclusion / exclusion ---

  def test_accepted_event_is_included
    insert_event(EventId: 1, Title: 'My LARP')
    insert_bid(event_id: 1, status: 'Accepted')
    results = export
    assert_equal 1, results.size
    assert_equal 'My LARP', results.first[:title]
  end

  def test_dropped_event_is_included_with_dropped_status
    insert_event(EventId: 1)
    insert_bid(event_id: 1, status: 'Dropped')
    results = export
    assert_equal 1, results.size
    assert_equal 'dropped', results.first[:status]
  end

  def test_special_event_included_without_bid
    insert_event(EventId: 1, Title: 'Opening Ceremonies', SpecialEvent: 1)
    results = export
    assert_equal 1, results.size
    assert_equal 'active', results.first[:status]
  end

  def test_event_without_bid_is_excluded
    insert_event(EventId: 1)
    assert_empty export
  end

  def test_event_with_pending_bid_is_excluded
    insert_event(EventId: 1)
    insert_bid(event_id: 1, status: 'Pending')
    assert_empty export
  end

  # --- event categories ---

  def test_larp_event_category
    insert_event(EventId: 1, GameType: 'LARP')
    insert_bid(event_id: 1, status: 'Accepted')
    assert_equal 'LARP', export.first[:event_category_name]
  end

  def test_tabletop_rpg_event_category
    insert_event(EventId: 1, GameType: 'Tabletop RPG')
    insert_bid(event_id: 1, status: 'Accepted')
    assert_equal 'Tabletop RPG', export.first[:event_category_name]
  end

  def test_board_game_event_category
    insert_event(EventId: 1, GameType: 'Board Game')
    insert_bid(event_id: 1, status: 'Accepted')
    assert_equal 'Board Game', export.first[:event_category_name]
  end

  def test_ops_event_yields_volunteer_event_category
    insert_event(EventId: 1, IsOps: 'Y', GameType: 'LARP')
    insert_bid(event_id: 1, status: 'Accepted')
    assert_equal 'Volunteer Event', export.first[:event_category_name]
  end

  def test_panel_special_event_category
    insert_event(EventId: 1, Title: 'PANEL: Design Talks', SpecialEvent: 1)
    results = export
    assert_equal 'Panel', results.first[:event_category_name]
  end

  def test_panel_prefix_stripped_from_title
    insert_event(EventId: 1, Title: 'PANEL: Design Talks', SpecialEvent: 1)
    assert_equal 'Design Talks', export.first[:title]
  end

  def test_filler_special_event_without_prefix
    insert_event(EventId: 1, Title: 'Opening Ceremonies', SpecialEvent: 1)
    assert_equal 'Filler', export.first[:event_category_name]
  end

  # --- registration policies ---

  def test_larp_gets_gender_buckets
    insert_event(
      EventId: 1, GameType: 'LARP',
      MaxPlayersMale: 3, MinPlayersMale: 1, PrefPlayersMale: 2,
      MaxPlayersFemale: 4, MinPlayersFemale: 1, PrefPlayersFemale: 3,
      MaxPlayersNeutral: 2, MinPlayersNeutral: 0, PrefPlayersNeutral: 2
    )
    insert_bid(event_id: 1, status: 'Accepted')
    policy = export.first[:registration_policy]
    keys = policy[:buckets].map { |b| b[:key] }
    assert_includes keys, 'male'
    assert_includes keys, 'female'
    assert_includes keys, 'flex'
  end

  def test_board_game_gets_unlimited_policy
    insert_event(EventId: 1, GameType: 'Board Game')
    insert_bid(event_id: 1, status: 'Accepted')
    policy = export.first[:registration_policy]
    assert_equal 1, policy[:buckets].size
    assert_equal false, policy[:buckets].first[:slots_limited]
  end

  # --- duration ---

  def test_hours_converted_to_seconds
    insert_event(EventId: 1, GameType: 'LARP', Hours: 3)
    insert_bid(event_id: 1, status: 'Accepted')
    assert_equal 10_800, export.first[:length_seconds]
  end

  # --- id_map population ---

  def test_id_map_populated
    insert_event(EventId: 42, Title: 'Test')
    insert_bid(event_id: 42, status: 'Accepted')
    table = IntercodeImport::Intercode1::Tables::Events.new(@db)
    table.export!
    assert_equal '42', table.id_map[42]
  end

  # --- used_event_categories ---

  def test_used_event_categories_returns_only_seen_categories
    insert_event(EventId: 1, GameType: 'Board Game')
    insert_bid(event_id: 1, status: 'Accepted')
    table = IntercodeImport::Intercode1::Tables::Events.new(@db)
    table.export!
    category_names = table.used_event_categories.map { |c| c[:name] }
    assert_includes category_names, 'Board Game'
    refute_includes category_names, 'LARP'
  end
end
