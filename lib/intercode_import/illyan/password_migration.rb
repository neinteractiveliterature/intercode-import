# frozen_string_literal: true

require 'bcrypt'

module IntercodeImport
  module Illyan
    module PasswordMigration
      def password_hash_for(illyan_row)
        return nil unless illyan_row

        if illyan_row[:encrypted_password].present?
          illyan_row[:encrypted_password]
        elsif illyan_row[:legacy_password_sha1].present?
          BCrypt::Password.create(illyan_row[:legacy_password_sha1]).to_s
        elsif illyan_row[:legacy_password_md5].present?
          BCrypt::Password.create(illyan_row[:legacy_password_md5]).to_s
        end
      end
    end
  end
end
