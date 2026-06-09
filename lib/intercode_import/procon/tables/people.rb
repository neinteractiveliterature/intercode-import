# frozen_string_literal: true

require_relative '../../illyan/password_migration'

module IntercodeImport
  module Procon
    module Tables
      class People < Procon::Table
        include Illyan::PasswordMigration

        def initialize(procon_connection, illyan_connection)
          super(procon_connection)
          @illyan_connection = illyan_connection
        end

        def export!
          logger.info 'Exporting People (ProCon users)'
          users = []
          seen_emails = {}

          dataset.each do |row|
            email = row[:email].to_s.downcase.strip
            next if email.blank?

            illyan_row = @illyan_connection[:people].where(email: email).first

            unless illyan_row || seen_emails[email]
              logger.warn "Skipping #{email}: no Illyan record"
              next
            end

            unless seen_emails[email]
              password_hash = password_hash_for(illyan_row)
              users << {
                email: email,
                first_name: row[:firstname].presence || email,
                last_name: row[:lastname].presence || '',
                password_hash: password_hash
              }.compact
              seen_emails[email] = true
            end

            id_map[row[:id]] = email
          end

          users
        end

        private

        def row_id(row) = row[:id]
      end
    end
  end
end
