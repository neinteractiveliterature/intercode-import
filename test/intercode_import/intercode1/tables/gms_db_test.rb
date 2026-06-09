# frozen_string_literal: true

require 'test_helper'

class GmsDbTest < Minitest::Test
  include DbTestHelper

  def self.setup_db(db)
    db.create_table!(:GMs) do
      Integer   :GMId, primary_key: true
      Integer   :EventId
      Integer   :UserId
      TrueClass :DisplayAsGM,       default: false
      TrueClass :DisplayEMail,      default: false
      TrueClass :ReceiveConEMail,   default: false
      TrueClass :ReceiveSignupEMail, default: false
    end
  end

  def self.teardown_db(db)
    db.drop_table?(:GMs)
  end

  def truncate_tables(db)
    db[:GMs].delete
  end

  def insert_gm(overrides = {})
    defaults = {
      GMId: 1, EventId: 10, UserId: 20,
      DisplayAsGM: false, DisplayEMail: false,
      ReceiveConEMail: false, ReceiveSignupEMail: false
    }
    @db[:GMs].insert(defaults.merge(overrides))
  end

  def export(event_id_map: { 10 => 'event-10' }, user_map: { 20 => 'gm@example.com' })
    IntercodeImport::Intercode1::Tables::GMs.new(@db, event_id_map, user_map).export!
  end

  def test_single_gm_exported
    insert_gm(GMId: 1, EventId: 10, UserId: 20, DisplayAsGM: true)
    results = export
    assert_equal 1, results.size
    gm = results.first
    assert_equal 'event-10', gm[:event_id]
    assert_equal 'gm@example.com', gm[:user_email]
  end

  def test_display_as_gm_true
    insert_gm(GMId: 1, DisplayAsGM: true)
    assert export.first[:display]
  end

  def test_display_as_gm_false
    insert_gm(GMId: 1, DisplayAsGM: false)
    refute export.first[:display]
  end

  def test_receive_signup_email_true_becomes_all_signups
    insert_gm(GMId: 1, ReceiveSignupEMail: true)
    assert_equal 'all_signups', export.first[:receive_signup_email]
  end

  def test_receive_signup_email_false_becomes_no
    insert_gm(GMId: 1, ReceiveSignupEMail: false)
    assert_equal 'no', export.first[:receive_signup_email]
  end

  def test_duplicate_event_user_pair_merged_into_one_record
    insert_gm(GMId: 1, EventId: 10, UserId: 20, DisplayAsGM: false)
    insert_gm(GMId: 2, EventId: 10, UserId: 20, DisplayAsGM: true)
    results = export
    assert_equal 1, results.size
  end

  def test_merged_record_ors_boolean_flags
    insert_gm(GMId: 1, EventId: 10, UserId: 20, DisplayAsGM: false, DisplayEMail: true)
    insert_gm(GMId: 2, EventId: 10, UserId: 20, DisplayAsGM: true,  DisplayEMail: false)
    gm = export.first
    assert gm[:display]
    assert gm[:show_email]
  end

  def test_different_events_produce_separate_records
    insert_gm(GMId: 1, EventId: 10, UserId: 20)
    insert_gm(GMId: 2, EventId: 11, UserId: 20)
    assert_equal 2, export(event_id_map: { 10 => 'event-10', 11 => 'event-11' }).size
  end

  def test_unknown_event_id_skipped
    insert_gm(GMId: 1, EventId: 999, UserId: 20)
    assert_empty export
  end

  def test_unknown_user_id_skipped
    insert_gm(GMId: 1, EventId: 10, UserId: 999)
    assert_empty export
  end
end
