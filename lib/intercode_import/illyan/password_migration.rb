# frozen_string_literal: true

require 'bcrypt'

module IntercodeImport
  module Illyan
    module PasswordMigration
      # Returns a hash with :password_hash, :password_hash_type, and :password_sha1_salt,
      # or nil if no password data is available.
      def password_hash_for(illyan_row)
        return nil unless illyan_row

        if illyan_row[:encrypted_password].present?
          { password_hash: illyan_row[:encrypted_password], password_hash_type: 'bcrypt' }
        elsif illyan_row[:legacy_password_sha1].present?
          {
            password_hash: BCrypt::Password.create(illyan_row[:legacy_password_sha1]).to_s,
            password_hash_type: 'bcrypt_wrapped_sha1',
            password_sha1_salt: illyan_row[:legacy_password_sha1_salt].presence
          }.compact
        elsif illyan_row[:legacy_password_md5].present?
          {
            password_hash: BCrypt::Password.create(illyan_row[:legacy_password_md5]).to_s,
            password_hash_type: 'bcrypt_wrapped_md5'
          }
        end
      end
    end
  end
end
