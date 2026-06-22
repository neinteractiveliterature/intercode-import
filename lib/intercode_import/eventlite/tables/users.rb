# frozen_string_literal: true

module IntercodeImport
  module Eventlite
    module Tables
      class Users < Eventlite::Table
        def initialize(connection)
          super
          @names_by_user_id = load_names_from_tickets
        end

        def export!
          logger.info 'Exporting Users'
          results = []
          seen_emails = {}

          dataset.each do |row|
            email = row[:email].to_s.downcase.strip
            next if email.blank?
            next if seen_emails[email]

            seen_emails[email] = true
            first_name, last_name = parse_name(@names_by_user_id[row[:id]])

            record = {
              email: email,
              first_name: first_name,
              last_name: last_name
            }

            if row[:encrypted_password].present?
              record[:password_hash] = row[:encrypted_password]
              record[:password_hash_type] = 'bcrypt'
            end

            id_map[row[:id]] = email
            results << record
          end

          results
        end

        private

        def load_names_from_tickets
          connection[:tickets].select(:user_id, :name).all.each_with_object({}) do |row, h|
            next if h[row[:user_id]] || row[:name].to_s.blank?
            h[row[:user_id]] = row[:name].to_s.strip
          end
        end

        def parse_name(full_name)
          return ['', ''] if full_name.blank?
          parts = full_name.strip.split(' ', 2)
          [parts[0] || '', parts[1] || '']
        end
      end
    end
  end
end
