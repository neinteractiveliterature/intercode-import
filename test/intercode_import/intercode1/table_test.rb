# frozen_string_literal: true

require 'test_helper'

class Intercode1TableTest < Minitest::Test
  class TestTable < IntercodeImport::Intercode1::Table
    public :yesno_to_bool, :yn_to_bool
  end

  def setup
    @table = TestTable.new(nil)
  end

  def test_yesno_yes
    assert_equal true, @table.yesno_to_bool('Yes')
  end

  def test_yesno_no
    assert_equal false, @table.yesno_to_bool('No')
  end

  def test_yesno_unknown_raises_without_default
    assert_raises(RuntimeError) { @table.yesno_to_bool('Maybe') }
  end

  def test_yesno_unknown_returns_default
    assert_equal false, @table.yesno_to_bool('Maybe', false)
    assert_equal true,  @table.yesno_to_bool('', true)
  end

  def test_yn_y
    assert_equal true, @table.yn_to_bool('Y')
  end

  def test_yn_n
    assert_equal false, @table.yn_to_bool('N')
  end

  def test_yn_unknown_raises_without_default
    assert_raises(RuntimeError) { @table.yn_to_bool('X') }
  end

  def test_yn_unknown_returns_default
    assert_equal true,  @table.yn_to_bool('X', true)
    assert_equal false, @table.yn_to_bool(nil, false)
  end
end
