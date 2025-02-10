# frozen_string_literal: true

module JobHelpers
  class EncryptionHelper
    def decrypt(data:, iv:, key:)
      cipher = build_cipher
      cipher.decrypt
      cipher.iv = iv
      cipher.key = key
      cipher.auth_data = ''
      cipher.auth_tag = data[-16..-1]

      cipher.update(data[0..-17]) + cipher.final
    end

    def encrypt(data:, iv:, key:)
      cipher = build_cipher
      cipher.encrypt
      cipher.iv = iv
      cipher.key = key
      cipher.auth_data = ''

      encrypted = cipher.update(data) + cipher.final
      tag = cipher.auth_tag # produces 16 bytes tag by default

      encrypted + tag
    end

    def build_cipher
      require 'openssl'

      OpenSSL::Cipher.new('aes-256-gcm')
    end
  end
end
