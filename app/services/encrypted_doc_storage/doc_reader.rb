# frozen_string_literal: true

module EncryptedDocStorage
  class DocReader
    # @param [#read_image] storage backend the object was written to
    def initialize(storage: RedisStorage.new)
      @storage = storage
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

    attr_reader :storage

    def aes_cipher
      @aes_cipher ||= Encryption::AesCipherV2.new
    end
  end
end
