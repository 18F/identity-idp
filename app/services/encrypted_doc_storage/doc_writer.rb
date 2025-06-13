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

      storage.write_image(
        encrypted_image: aes_cipher.encrypt(image, key),
        name:,
      )

      Result.new(
        name:,
        encryption_key: Base64.strict_encode64(key),
      )
    end

    def write_with_data(image:, data:)
      img_key = data.find { |k, _v| k.match?(/_encryption_key$/) }.last
      name = data.find { |k, _v| k.match?(/_file_id$/) }.last

      storage.write_image(
        encrypted_image: aes_cipher.encrypt(image, Base64.strict_decode64(img_key)),
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
