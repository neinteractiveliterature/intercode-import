# frozen_string_literal: true

require 'test_helper'

class EventliteUsersDbTest < Minitest::Test
  include EventliteDbTestHelper

  def self.setup_db(db)
    db.create_table!(:users) do
      primary_key :id
      String  :email
      String  :encrypted_password
      TrueClass :admin, default: false
    end
    db.create_table!(:events) do
      primary_key :id
      String :name
      String :slug
    end
    db.create_table!(:ticket_types) do
      primary_key :id
      Integer :event_id
      String  :name
    end
    db.create_table!(:tickets) do
      primary_key :id
      Integer :ticket_type_id
      Integer :user_id
      String  :name
      String  :email
      String  :phone
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

  def insert_user(overrides = {})
    defaults = { email: 'alice@example.com', encrypted_password: '$2a$12$fakehash', admin: false }
    @db[:users].insert(defaults.merge(overrides))
  end

  def insert_event(overrides = {})
    @db[:events].insert({ name: 'Test Event', slug: 'test-event' }.merge(overrides))
  end

  def insert_ticket_type(overrides = {})
    @db[:ticket_types].insert({ name: 'General' }.merge(overrides))
  end

  def insert_ticket(overrides = {})
    @db[:tickets].insert(overrides)
  end

  def export_users
    IntercodeImport::Eventlite::Tables::Users.new(@db).export!
  end

  def test_basic_user_exported
    insert_user(email: 'bob@example.com', encrypted_password: '$2a$12$somehash')
    users = export_users
    assert_equal 1, users.size
    assert_equal 'bob@example.com', users.first[:email]
    assert_equal '$2a$12$somehash', users.first[:password_hash]
    assert_equal 'bcrypt', users.first[:password_hash_type]
  end

  def test_blank_email_skipped
    insert_user(email: '')
    assert_empty export_users
  end

  def test_email_normalised_to_lowercase
    insert_user(email: 'BOB@EXAMPLE.COM')
    assert_equal 'bob@example.com', export_users.first[:email]
  end

  def test_duplicate_email_exported_once
    insert_user(id: 1, email: 'dupe@example.com')
    insert_user(id: 2, email: 'dupe@example.com')
    assert_equal 1, export_users.size
  end

  def test_name_inferred_from_ticket
    uid = insert_user(email: 'jane@example.com')
    eid = insert_event
    ttid = insert_ticket_type(event_id: eid)
    insert_ticket(ticket_type_id: ttid, user_id: uid, name: 'Jane Smith')
    users = export_users
    assert_equal 'Jane', users.first[:first_name]
    assert_equal 'Smith', users.first[:last_name]
  end

  def test_single_word_name_uses_empty_last_name
    uid = insert_user(email: 'mono@example.com')
    eid = insert_event
    ttid = insert_ticket_type(event_id: eid)
    insert_ticket(ticket_type_id: ttid, user_id: uid, name: 'Madonna')
    users = export_users
    assert_equal 'Madonna', users.first[:first_name]
    assert_equal '', users.first[:last_name]
  end

  def test_multi_word_last_name_preserved
    uid = insert_user(email: 'multi@example.com')
    eid = insert_event
    ttid = insert_ticket_type(event_id: eid)
    insert_ticket(ticket_type_id: ttid, user_id: uid, name: 'Jean-Luc Picard Smith')
    users = export_users
    assert_equal 'Jean-Luc', users.first[:first_name]
    assert_equal 'Picard Smith', users.first[:last_name]
  end

  def test_empty_first_and_last_name_when_no_ticket
    insert_user(email: 'notix@example.com')
    users = export_users
    assert_equal '', users.first[:first_name]
    assert_equal '', users.first[:last_name]
  end

  def test_id_map_keyed_by_database_id
    uid = insert_user(email: 'map@example.com')
    table = IntercodeImport::Eventlite::Tables::Users.new(@db)
    table.export!
    assert_equal 'map@example.com', table.id_map[uid]
  end

  def test_ticket_only_user_included
    eid = insert_event
    ttid = insert_ticket_type(event_id: eid)
    insert_ticket(ticket_type_id: ttid, user_id: nil, email: 'guest@example.com', name: 'Guest User')
    users = export_users
    assert_equal 1, users.size
    u = users.first
    assert_equal 'guest@example.com', u[:email]
    assert_equal 'Guest', u[:first_name]
    assert_equal 'User', u[:last_name]
    refute u.key?(:password_hash)
  end

  def test_ticket_only_user_not_duplicated_when_user_account_exists
    insert_user(email: 'overlap@example.com', encrypted_password: '$2a$12$hash')
    eid = insert_event
    ttid = insert_ticket_type(event_id: eid)
    insert_ticket(ticket_type_id: ttid, user_id: nil, email: 'overlap@example.com', name: 'Overlap User')
    users = export_users
    assert_equal 1, users.size
    assert users.first[:password_hash]
  end

  def test_ticket_only_users_deduplicated_across_tickets
    eid = insert_event
    ttid = insert_ticket_type(event_id: eid)
    insert_ticket(ticket_type_id: ttid, user_id: nil, email: 'dupe@example.com', name: 'Dupe One')
    insert_ticket(ticket_type_id: ttid, user_id: nil, email: 'dupe@example.com', name: 'Dupe Two')
    assert_equal 1, export_users.size
  end
end
