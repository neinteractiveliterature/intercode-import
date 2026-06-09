# frozen_string_literal: true

require 'test_helper'

class RegistrationPolicyHelpersTest < Minitest::Test
  class Helper
    include IntercodeImport::Intercode1::RegistrationPolicyHelpers
    public :bucket_for_gender
  end

  def setup
    @h = Helper.new
  end

  def test_unlimited_policy_structure
    policy = @h.unlimited_registration_policy
    assert_equal 1, policy[:buckets].length
    bucket = policy[:buckets].first
    assert_equal 'unlimited', bucket[:key]
    assert_equal false, bucket[:slots_limited]
  end

  def test_empty_policy
    assert_equal({ buckets: [] }, @h.empty_registration_policy)
  end

  def test_bucket_for_male
    row = { MaxPlayersMale: 5, MinPlayersMale: 2, PrefPlayersMale: 4 }
    b = @h.bucket_for_gender(row, 'Male')
    assert_equal 'male', b[:key]
    assert_equal 'Male role', b[:name]
    assert_equal 5, b[:total_slots]
    assert_equal 2, b[:minimum_slots]
    assert_equal 4, b[:preferred_slots]
    assert_equal true, b[:slots_limited]
    assert_equal false, b[:anything]
  end

  def test_bucket_for_neutral_is_flex
    row = { MaxPlayersNeutral: 10, MinPlayersNeutral: 0, PrefPlayersNeutral: 8 }
    b = @h.bucket_for_gender(row, 'Neutral')
    assert_equal 'flex', b[:key]
    assert_equal 'Flex', b[:name]
    assert_equal true, b[:anything]
  end

  def test_policy_with_male_and_female_slots
    row = {
      MaxPlayersMale: 3, MinPlayersMale: 1, PrefPlayersMale: 2,
      MaxPlayersFemale: 4, MinPlayersFemale: 1, PrefPlayersFemale: 3,
      MaxPlayersNeutral: 0, MinPlayersNeutral: 0, PrefPlayersNeutral: 0
    }
    policy = @h.registration_policy_from_row(row)
    keys = policy[:buckets].map { |b| b[:key] }
    assert_includes keys, 'male'
    assert_includes keys, 'female'
    refute_includes keys, 'flex'
  end

  def test_policy_only_neutral_slots_becomes_signups_bucket
    row = {
      MaxPlayersMale: 0, MinPlayersMale: 0, PrefPlayersMale: 0,
      MaxPlayersFemale: 0, MinPlayersFemale: 0, PrefPlayersFemale: 0,
      MaxPlayersNeutral: 6, MinPlayersNeutral: 3, PrefPlayersNeutral: 5
    }
    policy = @h.registration_policy_from_row(row)
    assert_equal 1, policy[:buckets].length
    bucket = policy[:buckets].first
    assert_equal 'signups', bucket[:key]
    assert_equal 'Signups', bucket[:name]
    assert_equal false, bucket[:anything]
  end

  def test_policy_with_male_female_and_flex
    row = {
      MaxPlayersMale: 2, MinPlayersMale: 1, PrefPlayersMale: 2,
      MaxPlayersFemale: 2, MinPlayersFemale: 1, PrefPlayersFemale: 2,
      MaxPlayersNeutral: 3, MinPlayersNeutral: 0, PrefPlayersNeutral: 2
    }
    policy = @h.registration_policy_from_row(row)
    keys = policy[:buckets].map { |b| b[:key] }
    assert_includes keys, 'male'
    assert_includes keys, 'female'
    assert_includes keys, 'flex'
  end
end
