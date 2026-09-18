# frozen_string_literal: true

module EncryptedDocStorage
  class DocReader
    def initialize(s3_enabled: false)
      @s3_enabled = s3_enabled
    end

    # @param [String] name storage object name (e.g. "encrypted_images/<uuid>")
    # @param [String] encryption_key Base64-encoded AES-256 key
    # @return [String, nil] the decrypted image bytes, or nil if the object is
    #   missing or cannot be decrypted (corrupt object or unusable key)
    def read(name:, encryption_key:)
      encrypted_image = storage.read_image(name:)
      return nil if encrypted_image.blank? || encryption_key.blank?

      aes_cipher.decrypt(encrypted_image, Base64.strict_decode64(encryption_key))
    rescue Encryption::EncryptionError, ArgumentError
      nil
    end

    private

    def aes_cipher
      @aes_cipher ||= Encryption::AesCipherV2.new
    end

    def storage
      @storage ||= @s3_enabled ? S3Storage.new : LocalStorage.new
    end
  end
end
