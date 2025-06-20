# frozen_string_literal: true

module EncryptedDocStorage
  class DocWriter
    Result = Struct.new(
      :name,
      :encryption_key,
    )

    def initialize(s3_enabled: false)
      @s3_enabled = s3_enabled
    end

    def write(image: nil)
      if image.blank?
        return Result.new(name: nil, encryption_key: nil)
      end

      name = SecureRandom.uuid

      write_with_data(
        image:,
        encryption_key: key,
        name:,
      )

      Result.new(
        name:,
        encryption_key: Base64.strict_encode64(key),
      )
    end

    def write_with_data(image:, encryption_key:, name:)
      storage.write_image(
        encrypted_image: aes_cipher.encrypt(image, encryption_key),
        name:,
      )
    end

    private

    def aes_cipher
      @aes_cipher ||= Encryption::AesCipherV2.new
    end

    def storage
      @storage ||= begin
        @s3_enabled ? S3Storage.new : LocalStorage.new
      end
    end

    def key
      @key ||= SecureRandom.bytes(32)
    end
  end
end
