# frozen_string_literal: true

require 'test_helper'

class DateHelpersTest < Minitest::Test
  include IntercodeImport::Intercode1::DateHelpers

  TZ = 'US/Eastern'
  EASTERN = ActiveSupport::TimeZone[TZ]

  def test_friday_start_when_convention_starts_on_friday
    starts_at = EASTERN.parse('2024-04-05 10:00:00')
    result = friday_start(TZ, starts_at)
    assert result.friday?
    assert_equal 0, result.hour
    assert_equal 0, result.min
    assert_equal 0, result.sec
  end

  def test_friday_start_when_convention_starts_on_thursday
    starts_at = EASTERN.parse('2024-04-04 18:00:00')
    result = friday_start(TZ, starts_at)
    assert result.friday?
    assert_equal 0, result.hour
  end

  def test_friday_start_raises_for_non_thursday_friday
    starts_at = EASTERN.parse('2024-04-06 10:00:00') # Saturday
    assert_raises(RuntimeError) { friday_start(TZ, starts_at) }
  end

  def test_start_of_convention_day_thursday
    starts_at = EASTERN.parse('2024-04-04 18:00:00') # Thursday start
    result = start_of_convention_day(TZ, starts_at, 'Thu')
    assert result.thursday?
    assert_equal 0, result.hour
  end

  def test_start_of_convention_day_friday
    starts_at = EASTERN.parse('2024-04-05 10:00:00') # Friday start
    result = start_of_convention_day(TZ, starts_at, 'Fri')
    assert result.friday?
  end

  def test_start_of_convention_day_saturday
    starts_at = EASTERN.parse('2024-04-05 10:00:00') # Friday start
    result = start_of_convention_day(TZ, starts_at, 'Sat')
    assert result.saturday?
  end

  def test_start_of_convention_day_sunday
    starts_at = EASTERN.parse('2024-04-05 10:00:00') # Friday start
    result = start_of_convention_day(TZ, starts_at, 'Sun')
    assert result.sunday?
  end

  def test_consecutive_days_are_24_hours_apart
    starts_at = EASTERN.parse('2024-04-05 10:00:00')
    fri = start_of_convention_day(TZ, starts_at, 'Fri')
    sat = start_of_convention_day(TZ, starts_at, 'Sat')
    assert_equal 24 * 3600, sat - fri
  end
end
