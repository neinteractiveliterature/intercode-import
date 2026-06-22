# frozen_string_literal: true

# Mixin for Eventlite integration tests that need a live PostgreSQL connection.
# Set EVENTLITE_TEST_DATABASE_URL to a postgres:// URL to run these tests.
module EventliteDbTestHelper
  UNSET = Object.new.freeze
  private_constant :UNSET

  def self.included(base)
    base.instance_variable_set(:@_db_conn, UNSET)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def db_connection
      if @_db_conn.equal?(UNSET)
        @_db_conn =
          if ENV['EVENTLITE_TEST_DATABASE_URL']
            db = Sequel.connect(ENV['EVENTLITE_TEST_DATABASE_URL'])
            setup_db(db)
            Minitest.after_run { teardown_db(db); db.disconnect }
            db
          end
      end
      @_db_conn
    end

    def setup_db(_db) = nil
    def teardown_db(_db) = nil
  end

  def setup
    skip 'Set EVENTLITE_TEST_DATABASE_URL to run Eventlite DB integration tests' unless self.class.db_connection
    @db = self.class.db_connection
    truncate_tables(@db)
  end

  def truncate_tables(_db) = nil
end
