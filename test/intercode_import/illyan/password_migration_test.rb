# frozen_string_literal: true

require 'test_helper'
require 'bcrypt'

class PasswordMigrationTest < Minitest::Test
  class Helper
    include IntercodeImport::Illyan::PasswordMigration
  end

  def setup
    @h = Helper.new
  end

  def test_nil_row_returns_nil
    assert_nil @h.password_hash_for(nil)
  end

  def test_empty_row_returns_nil
    assert_nil @h.password_hash_for({})
  end

  def test_bcrypt_password_returned_as_is
    hash = '$2a$12$KIXJqRfuIkAzB5aGKIFqXOqD3lY8sQZl.bFNmqBxU3HkmJYoFf7fq'
    result = @h.password_hash_for({ encrypted_password: hash })
    assert_equal 'bcrypt', result[:password_hash_type]
    assert_equal hash, result[:password_hash]
    refute result.key?(:password_sha1_salt)
  end

  def test_sha1_password_is_bcrypt_wrapped
    sha1 = 'abc123deadbeef' * 2
    result = @h.password_hash_for({ encrypted_password: nil, legacy_password_sha1: sha1 })
    assert_equal 'bcrypt_wrapped_sha1', result[:password_hash_type]
    assert BCrypt::Password.new(result[:password_hash]).is_password?(sha1)
    refute result.key?(:password_sha1_salt)
  end

  def test_sha1_password_includes_salt_when_present
    sha1 = 'hashvalue'
    salt = 'somesalt'
    result = @h.password_hash_for({
      encrypted_password: nil,
      legacy_password_sha1: sha1,
      legacy_password_sha1_salt: salt
    })
    assert_equal salt, result[:password_sha1_salt]
  end

  def test_sha1_salt_absent_when_blank
    result = @h.password_hash_for({
      encrypted_password: nil,
      legacy_password_sha1: 'hash',
      legacy_password_sha1_salt: ''
    })
    refute result.key?(:password_sha1_salt)
  end

  def test_md5_password_is_bcrypt_wrapped
    md5 = 'd41d8cd98f00b204e9800998ecf8427e'
    result = @h.password_hash_for({ encrypted_password: nil, legacy_password_sha1: nil, legacy_password_md5: md5 })
    assert_equal 'bcrypt_wrapped_md5', result[:password_hash_type]
    assert BCrypt::Password.new(result[:password_hash]).is_password?(md5)
    refute result.key?(:password_sha1_salt)
  end

  def test_bcrypt_takes_precedence_over_sha1
    result = @h.password_hash_for({
      encrypted_password: '$2a$12$somehash',
      legacy_password_sha1: 'sha1value'
    })
    assert_equal 'bcrypt', result[:password_hash_type]
  end

  def test_sha1_takes_precedence_over_md5
    result = @h.password_hash_for({
      encrypted_password: nil,
      legacy_password_sha1: 'sha1value',
      legacy_password_md5: 'md5value'
    })
    assert_equal 'bcrypt_wrapped_sha1', result[:password_hash_type]
  end
end
