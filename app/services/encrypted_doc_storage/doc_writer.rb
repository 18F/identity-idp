# frozen_string_literal: true

module EncryptedDocStorage
  class DocWriter
    Result = Struct.new(
      :name,
      :encryption_key,
    )

    def write(image:, data_store: LocalStorage)
      name = SecureRandom.uuid
      storage = data_store.new

      storage.write_image(
        encrypted_image: aes_cipher.encrypt(image, key),
        name:,
      )

      Result.new(
        name:,
        encryption_key: Base64.strict_encode64(key),
      )
    end

    private

    def aes_cipher
      @aes_cipher ||= Encryption::AesCipherV2.new
    end

    def key
      @key ||= SecureRandom.bytes(32)
    end
  end
end
