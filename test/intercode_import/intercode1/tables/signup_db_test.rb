# frozen_string_literal: true

require 'test_helper'

class SignupDbTest < Minitest::Test
  include DbTestHelper

  def self.setup_db(db)
    db.create_table!(:Signup) do
      Integer  :SignupId, primary_key: true
      Integer  :RunId
      Integer  :UserId
      String   :Counted, size: 1   # 'Y' or 'N'
      String   :State
      String   :Gender
      DateTime :TimeStamp
    end
  end

  def self.teardown_db(db)
    db.drop_table?(:Signup)
  end

  def truncate_tables(db)
    db[:Signup].delete
  end

  # run_id_map maps RunId (int) → { event_id:, run_index: }
  # user_con_profile_id_map maps UserId (int) → email string
  # registration_policy_by_event_id maps event_id string → policy hash

  MALE_FEMALE_POLICY = {
    buckets: [
      { key: 'male',   name: 'Male role', slots_limited: true, anything: false, total_slots: 1, minimum_slots: 0 },
      { key: 'female', name: 'Female role', slots_limited: true, anything: false, total_slots: 1, minimum_slots: 0 },
      { key: 'flex',   name: 'Flex', slots_limited: true, anything: true, total_slots: 2, minimum_slots: 0 }
    ]
  }.freeze

  def insert_signup(overrides = {})
    defaults = {
      SignupId: 1, RunId: 10, UserId: 20,
      Counted: 'Y', State: 'Confirmed',
      Gender: 'male', TimeStamp: Time.now
    }
    @db[:Signup].insert(defaults.merge(overrides))
  end

  def export(run_id_map: { 10 => { event_id: 'event-1', run_index: 0 } },
             user_map: { 20 => 'alice@example.com', 21 => 'bob@example.com' },
             policy_map: { 'event-1' => MALE_FEMALE_POLICY })
    IntercodeImport::Intercode1::Tables::Signup.new(@db, run_id_map, user_map, policy_map).export!
  end

  def test_confirmed_counted_signup_gets_matching_bucket
    insert_signup(UserId: 20, Gender: 'male', State: 'Confirmed', Counted: 'Y')
    result = export.first
    assert_equal 'male', result[:bucket_key]
    assert_equal 'male', result[:requested_bucket_key]
  end

  def test_confirmed_signup_falls_back_to_flex_when_bucket_full
    # Fill the male slot first
    insert_signup(SignupId: 1, UserId: 20, Gender: 'male', State: 'Confirmed', Counted: 'Y',
                  TimeStamp: Time.now - 60)
    # Second male signup should fall to flex
    insert_signup(SignupId: 2, UserId: 21, Gender: 'male', State: 'Confirmed', Counted: 'Y',
                  TimeStamp: Time.now)
    results = export
    assert_equal 2, results.size
    assert_equal 'male', results[0][:bucket_key]
    assert_equal 'flex', results[1][:bucket_key]
  end

  def test_waitlisted_signup_has_no_bucket_key
    insert_signup(State: 'Waitlisted', Counted: 'Y')
    result = export.first
    assert_nil result[:bucket_key]
    assert_equal 'waitlisted', result[:state]
  end

  def test_withdrawn_signup_exported_with_withdrawn_state
    insert_signup(State: 'Withdrawn', Counted: 'Y')
    result = export.first
    assert_equal 'withdrawn', result[:state]
  end

  def test_uncounted_signup_has_no_bucket_key
    insert_signup(Counted: 'N', State: 'Confirmed')
    result = export.first
    assert_nil result[:bucket_key]
    assert_nil result[:requested_bucket_key]
    assert_equal false, result[:counted]
  end

  def test_signup_referencing_unknown_run_is_skipped
    insert_signup(RunId: 999)
    assert_empty export
  end

  def test_signup_referencing_unknown_user_is_skipped
    insert_signup(UserId: 999)
    assert_empty export
  end

  def test_signup_includes_event_and_run_index
    insert_signup
    result = export.first
    assert_equal 'event-1', result[:event_id]
    assert_equal 0, result[:run_index]
  end

  def test_confirmed_counted_signup_with_no_available_bucket_omitted
    # Only a flex bucket, which is full; confirmed counted signup should be dropped
    full_flex_policy = {
      buckets: [
        { key: 'flex', name: 'Flex', slots_limited: true, anything: true, total_slots: 0, minimum_slots: 0 }
      ]
    }
    insert_signup(UserId: 20, Gender: 'neutral', State: 'Confirmed', Counted: 'Y')
    results = export(policy_map: { 'event-1' => full_flex_policy })
    assert_empty results
  end

  def test_signups_ordered_by_timestamp_for_consistent_bucket_assignment
    # Signup 2 has an earlier timestamp — it should get the male slot, signup 1 gets flex
    insert_signup(SignupId: 1, UserId: 20, Gender: 'male', State: 'Confirmed', Counted: 'Y',
                  TimeStamp: Time.now)
    insert_signup(SignupId: 2, UserId: 21, Gender: 'male', State: 'Confirmed', Counted: 'Y',
                  TimeStamp: Time.now - 3600)
    results = export
    assert_equal 2, results.size
    # The earlier signup (bob, id=2) should have been processed first → gets the male slot
    bob_result = results.find { |r| r[:user_email] == 'bob@example.com' }
    alice_result = results.find { |r| r[:user_email] == 'alice@example.com' }
    assert_equal 'male', bob_result[:bucket_key]
    assert_equal 'flex', alice_result[:bucket_key]
  end
end
