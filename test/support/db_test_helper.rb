# frozen_string_literal: true

# Mixin for integration tests that need a live MySQL connection.
# Include in a Minitest::Test subclass.
#
# Subclasses must override:
#   self.setup_db(db)   – create tables (use create_table! so leftover state is wiped)
#   self.teardown_db(db) – drop those tables
#   truncate_tables(db) – called before each test to clear row data
#
# The connection is created once per class and reused across all tests.
# Tests are skipped when TEST_DATABASE_URL is not set.
module DbTestHelper
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
          if ENV['TEST_DATABASE_URL']
            db = Sequel.connect(ENV['TEST_DATABASE_URL'])
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
    skip 'Set TEST_DATABASE_URL to run DB integration tests' unless self.class.db_connection
    @db = self.class.db_connection
    truncate_tables(@db)
  end

  def truncate_tables(_db) = nil
end
