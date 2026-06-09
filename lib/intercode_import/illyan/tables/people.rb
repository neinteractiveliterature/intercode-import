# frozen_string_literal: true

module IntercodeImport
  module Illyan
    module Tables
      class People < Illyan::Table
        include PasswordMigration

        def initialize(connection, emails)
          super(connection)
          @emails = emails
        end

        def dataset
          connection[:people].where(email: @emails)
        end

        def export!
          logger.info 'Exporting Illyan People'
          dataset.filter_map do |row|
            email = row[:email].to_s.downcase.strip
            next if email.blank?

            hash = password_hash_for(row)
            next unless hash

            id_map[row[:id]] = email
            {
              email: email,
              first_name: row[:firstname].presence || email,
              last_name: row[:lastname].presence || '',
              password_hash: hash
            }.compact
          end
        end
      end
    end
  end
end
