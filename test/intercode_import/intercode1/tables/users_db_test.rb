# frozen_string_literal: true

require 'test_helper'

class UsersDbTest < Minitest::Test
  include DbTestHelper

  def self.setup_db(db)
    db.create_table!(:Users) do
      Integer :UserId, primary_key: true
      String  :EMail
      String  :FirstName
      String  :LastName
      String  :Nickname
      String  :Address1
      String  :Address2
      String  :City
      String  :State
      String  :Zipcode
      String  :Country
      String  :DayPhone
      String  :EvePhone
      String  :BestTime
      String  :Gender
      Integer :BirthYear
      String  :PreferredContact
      String  :HowHeard
      String  :CanSignup
      Integer :CompEventId
      Integer :PaymentAmount
      String  :PaymentNote
      TrueClass :Staff,             default: false
      TrueClass :BidChair,          default: false
      TrueClass :BidCom,            default: false
      TrueClass :ConCom,            default: false
      TrueClass :GMLiaison,         default: false
      TrueClass :MailToAll,         default: false
      TrueClass :MailToAttendees,   default: false
      TrueClass :MailToGMs,         default: false
      TrueClass :Outreach,          default: false
      TrueClass :Scheduling,        default: false
    end
  end

  def self.teardown_db(db)
    db.drop_table?(:Users)
  end

  def truncate_tables(db)
    db[:Users].delete
  end

  def insert_user(overrides = {})
    defaults = {
      UserId: 1, EMail: 'alice@example.com',
      FirstName: 'Alice', LastName: 'Smith',
      CanSignup: 'Paid', PaymentAmount: 50,
      Staff: false, BidChair: false, BidCom: false, ConCom: false,
      GMLiaison: false, MailToAll: false, MailToAttendees: false,
      MailToGMs: false, Outreach: false, Scheduling: false
    }
    @db[:Users].insert(defaults.merge(overrides))
  end

  def export(event_id_map: {}, password_hashes: {})
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, event_id_map, password_hashes)
    table.export!
    table
  end

  # --- user export ---

  def test_basic_user_exported
    insert_user(EMail: 'bob@example.com', FirstName: 'Bob', LastName: 'Jones')
    users, _profiles, _tickets = export.then { |t| [t.instance_variable_get(:@__users), nil, nil] }
    # Export returns [users, profiles, tickets]
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    users, = table.export!
    assert_equal 1, users.size
    user = users.first
    assert_equal 'bob@example.com', user[:email]
    assert_equal 'Bob', user[:first_name]
    assert_equal 'Jones', user[:last_name]
  end

  def test_blank_email_user_is_skipped
    insert_user(UserId: 1, EMail: '')
    insert_user(UserId: 2, EMail: '   ')
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    users, profiles, tickets = table.export!
    assert_empty users
    assert_empty profiles
    assert_empty tickets
  end

  def test_duplicate_email_creates_one_user_two_profiles
    insert_user(UserId: 1, EMail: 'dupe@example.com', FirstName: 'First')
    insert_user(UserId: 2, EMail: 'dupe@example.com', FirstName: 'Second')
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    users, profiles, = table.export!
    assert_equal 1, users.size
    assert_equal 2, profiles.size
    assert profiles.all? { |p| p[:user_email] == 'dupe@example.com' }
  end

  def test_email_normalized_to_lowercase
    insert_user(EMail: 'UPPER@EXAMPLE.COM')
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    users, = table.export!
    assert_equal 'upper@example.com', users.first[:email]
  end

  # --- profiles ---

  def test_profile_includes_address_fields
    insert_user(
      EMail: 'addr@example.com',
      Address1: '123 Main St', City: 'Springfield',
      State: 'MA', Zipcode: '01234', Country: 'US'
    )
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    _, profiles, = table.export!
    p = profiles.first
    assert_equal 'Springfield', p[:city]
    assert_equal 'MA', p[:state]
    assert_equal '01234', p[:zipcode]
    assert_equal 'US', p[:country]
  end

  def test_profile_gender_lowercased
    insert_user(EMail: 'gen@example.com', Gender: 'Male')
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    _, profiles, = table.export!
    assert_equal 'male', profiles.first[:gender]
  end

  def test_profile_birth_year_converted_to_iso8601
    insert_user(EMail: 'bday@example.com', BirthYear: 1985)
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    _, profiles, = table.export!
    assert_equal '1985-01-01', profiles.first[:birth_date]
  end

  def test_profile_zero_birth_year_omitted
    insert_user(EMail: 'nobday@example.com', BirthYear: 0)
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    _, profiles, = table.export!
    refute profiles.first.key?(:birth_date)
  end

  def test_profile_preferred_contact_mapped
    insert_user(EMail: 'contact@example.com', PreferredContact: 'EMail')
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    _, profiles, = table.export!
    assert_equal 'email', profiles.first[:preferred_contact]
  end

  # --- tickets ---

  def test_paid_ticket_created
    insert_user(EMail: 'paid@example.com', CanSignup: 'Paid', PaymentAmount: 75)
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    _, _, tickets = table.export!
    assert_equal 1, tickets.size
    ticket = tickets.first
    assert_equal 'paid@example.com', ticket[:user_email]
    assert_equal 'Paid', ticket[:ticket_type_name]
    assert_equal({ fractional: 7500, currency_code: 'USD' }, ticket[:payment_amount])
  end

  def test_comp_ticket_with_event_includes_provided_by
    event_id_map = { 99 => 'event-99' }
    insert_user(EMail: 'comp@example.com', CanSignup: 'Comp', CompEventId: 99)
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, event_id_map, {})
    _, _, tickets = table.export!
    assert_equal 'event-99', tickets.first[:provided_by_event_id]
  end

  def test_no_ticket_when_can_signup_blank
    insert_user(EMail: 'notix@example.com', CanSignup: nil)
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    _, _, tickets = table.export!
    assert_empty tickets
  end

  # --- permissions ---

  def test_staff_flag_populates_accumulator
    insert_user(EMail: 'staff@example.com', Staff: true)
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    table.export!
    assert_includes table.staff_position_accumulator['Staff'][:user_emails], 'staff@example.com'
  end

  def test_bid_chair_flag_populates_accumulator_with_permissions
    insert_user(EMail: 'bc@example.com', BidChair: true)
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    table.export!
    assert_includes table.staff_position_accumulator['BidChair'][:permissions], 'read_event_proposals'
    assert_includes table.staff_position_accumulator['BidChair'][:user_emails], 'bc@example.com'
  end

  # --- id_map ---

  def test_id_map_keyed_by_user_id
    insert_user(UserId: 42, EMail: 'map@example.com')
    table = IntercodeImport::Intercode1::Tables::Users.new(@db, {}, {})
    table.export!
    assert_equal 'map@example.com', table.id_map[42]
  end
end
