# frozen_string_literal: true

require 'test_helper'

class EventliteTicketsDbTest < Minitest::Test
  include EventliteDbTestHelper

  def self.setup_db(db)
    db.create_table!(:users) do
      primary_key :id
      String :email
    end
    db.create_table!(:events) do
      primary_key :id
      String :name
    end
    db.create_table!(:ticket_types) do
      primary_key :id
      Integer :event_id
      String  :name
    end
    db.create_table!(:tickets) do
      primary_key :id
      Integer  :ticket_type_id
      Integer  :user_id
      String   :email
      DateTime :canceled_at
    end
  end

  def self.teardown_db(db)
    db.drop_table?(:tickets)
    db.drop_table?(:ticket_types)
    db.drop_table?(:events)
    db.drop_table?(:users)
  end

  def truncate_tables(db)
    db[:tickets].delete
    db[:ticket_types].delete
    db[:events].delete
    db[:users].delete
  end

  def setup
    super
    @event_id = @db[:events].insert(name: 'Test Event')
    @tt_id    = @db[:ticket_types].insert(event_id: @event_id, name: 'General')
    @user_id  = @db[:users].insert(email: 'alice@example.com')
    @ticket_type_names = { @tt_id => 'General' }
    @user_emails       = { @user_id => 'alice@example.com' }
  end

  def export_tickets
    IntercodeImport::Eventlite::Tables::Tickets.new(
      @db, @event_id, @ticket_type_names, @user_emails
    ).export!
  end

  def test_basic_ticket_exported
    @db[:tickets].insert(ticket_type_id: @tt_id, user_id: @user_id)
    tickets = export_tickets
    assert_equal 1, tickets.size
    assert_equal 'alice@example.com', tickets.first[:user_email]
    assert_equal 'General',           tickets.first[:ticket_type_name]
  end

  def test_canceled_ticket_excluded
    @db[:tickets].insert(ticket_type_id: @tt_id, user_id: @user_id, canceled_at: Time.now)
    assert_empty export_tickets
  end

  def test_ticket_for_different_event_excluded
    other_event_id = @db[:events].insert(name: 'Other Event')
    other_tt_id    = @db[:ticket_types].insert(event_id: other_event_id, name: 'VIP')
    @db[:tickets].insert(ticket_type_id: other_tt_id, user_id: @user_id)
    assert_empty export_tickets
  end

  def test_unknown_user_id_skipped
    @db[:tickets].insert(ticket_type_id: @tt_id, user_id: 9999)
    assert_empty export_tickets
  end

  def test_ticket_with_direct_email_exported
    @db[:tickets].insert(ticket_type_id: @tt_id, user_id: nil, email: 'guest@example.com')
    tickets = export_tickets
    assert_equal 1, tickets.size
    assert_equal 'guest@example.com', tickets.first[:user_email]
  end

  def test_ticket_with_nil_user_id_and_nil_email_skipped
    @db[:tickets].insert(ticket_type_id: @tt_id, user_id: nil, email: nil)
    assert_empty export_tickets
  end
end
