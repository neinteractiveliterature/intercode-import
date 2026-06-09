# frozen_string_literal: true

require 'test_helper'

class EventsTableTest < Minitest::Test
  def setup
    @events = IntercodeImport::Intercode1::Tables::Events.new(nil)
  end

  # category_key_for_game_type

  def test_board_game_category
    assert_equal 'board_game', @events.send(:category_key_for_game_type, 'Board Game')
  end

  def test_panel_category
    assert_equal 'panel', @events.send(:category_key_for_game_type, 'Panel')
  end

  def test_tabletop_rpg_category
    assert_equal 'tabletop_rpg', @events.send(:category_key_for_game_type, 'Tabletop RPG')
  end

  def test_other_game_type_returns_nil
    assert_nil @events.send(:category_key_for_game_type, 'Other')
  end

  def test_unknown_game_type_defaults_to_larp
    assert_equal 'larp', @events.send(:category_key_for_game_type, 'LARP')
    assert_equal 'larp', @events.send(:category_key_for_game_type, 'Something Else')
  end

  # raw_event_category_key

  def test_ops_flag_yields_volunteer_event
    row = { IsOps: 'Y', IsConSuite: 'N', SpecialEvent: 0, GameType: 'LARP' }
    assert_equal 'volunteer_event', @events.send(:raw_event_category_key, row)
  end

  def test_con_suite_flag_yields_volunteer_event
    row = { IsOps: 'N', IsConSuite: 'Y', SpecialEvent: 0, GameType: 'LARP' }
    assert_equal 'volunteer_event', @events.send(:raw_event_category_key, row)
  end

  def test_special_event_with_panel_prefix_yields_panel
    row = { IsOps: 'N', IsConSuite: 'N', SpecialEvent: 1, Title: 'PANEL: Something', GameType: nil }
    assert_equal 'panel', @events.send(:raw_event_category_key, row)
  end

  def test_special_event_without_prefix_yields_filler
    row = { IsOps: 'N', IsConSuite: 'N', SpecialEvent: 1, Title: 'Free Time', GameType: nil }
    assert_equal 'filler', @events.send(:raw_event_category_key, row)
  end

  def test_regular_event_delegates_to_game_type
    row = { IsOps: 'N', IsConSuite: 'N', SpecialEvent: 0, GameType: 'Tabletop RPG' }
    assert_equal 'tabletop_rpg', @events.send(:raw_event_category_key, row)
  end

  # event_title / parse_precon_prefix

  def test_event_title_strips_panel_prefix_with_colon
    row = { SpecialEvent: 1, Title: 'PANEL: My Interesting Panel' }
    assert_equal 'My Interesting Panel', @events.send(:event_title, row)
  end

  def test_event_title_strips_prefix_with_dash
    row = { SpecialEvent: 1, Title: 'DISCUSSION - Some Topic' }
    assert_equal 'Some Topic', @events.send(:event_title, row)
  end

  def test_event_title_strips_prefix_case_insensitively
    row = { SpecialEvent: 1, Title: 'Workshop: Hands-On Fun' }
    assert_equal 'Hands-On Fun', @events.send(:event_title, row)
  end

  def test_event_title_unchanged_for_regular_event
    row = { SpecialEvent: 0, Title: 'My Great LARP' }
    assert_equal 'My Great LARP', @events.send(:event_title, row)
  end

  def test_event_title_unchanged_for_special_event_without_prefix
    row = { SpecialEvent: 1, Title: 'Opening Ceremonies' }
    assert_equal 'Opening Ceremonies', @events.send(:event_title, row)
  end

  # unique_title

  def test_unique_title_first_occurrence
    assert_equal 'My Event', @events.send(:unique_title, 'My Event')
  end

  def test_unique_title_second_occurrence_gets_counter
    @events.send(:unique_title, 'Duplicate')
    assert_equal 'Duplicate [2]', @events.send(:unique_title, 'Duplicate')
  end

  def test_unique_title_third_occurrence_increments
    @events.send(:unique_title, 'Triple')
    @events.send(:unique_title, 'Triple')
    assert_equal 'Triple [3]', @events.send(:unique_title, 'Triple')
  end

  # event_status

  def test_active_status_for_accepted
    row = { SpecialEvent: nil, Status: 'Accepted' }
    assert_equal 'active', @events.send(:event_status, row)
  end

  def test_dropped_status_for_dropped
    row = { SpecialEvent: nil, Status: 'Dropped' }
    assert_equal 'dropped', @events.send(:event_status, row)
  end

  def test_active_status_for_special_event_regardless_of_bid_status
    row = { SpecialEvent: 1, Status: 'Dropped' }
    assert_equal 'active', @events.send(:event_status, row)
  end

  # con_mail_destination

  def test_game_mail_destination
    row = { ConMailDest: 'GameMail', GameEMail: 'gm@example.com' }
    assert_equal 'event_email', @events.send(:con_mail_destination, row)
  end

  def test_gms_destination
    row = { ConMailDest: 'GMs', GameEMail: nil }
    assert_equal 'gms', @events.send(:con_mail_destination, row)
  end

  def test_nil_destination_with_game_email_defaults_to_event_email
    row = { ConMailDest: nil, GameEMail: 'gm@example.com' }
    assert_equal 'event_email', @events.send(:con_mail_destination, row)
  end

  def test_nil_destination_without_game_email_defaults_to_gms
    row = { ConMailDest: nil, GameEMail: nil }
    assert_equal 'gms', @events.send(:con_mail_destination, row)
  end

  def test_unknown_destination_raises
    row = { ConMailDest: 'Unknown', GameEMail: nil }
    assert_raises(RuntimeError) { @events.send(:con_mail_destination, row) }
  end
end
