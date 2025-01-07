# frozen_string_literal: true

module EncryptedDocStorage
  class DocWriter
    Result = Struct.new(
      :front_uuid,
      :back_uuid,
      :encryption_key,
    )

    def write(front_image:, back_image:, data_store: LocalStorage)
      front_uuid = SecureRandom.uuid
      back_uuid = SecureRandom.uuid
      storage = data_store.new

      storage.write_image(
        encrypted_image: encrypted_image(front_image),
        name: front_uuid,
      )
      storage.write_image(
        encrypted_image: encrypted_image(back_image),
        name: back_uuid,
      )

      Result.new(
        front_uuid:,
        back_uuid:,
        encryption_key: Base64.strict_encode64(key),
      )
    end

    private

    def aes_cipher
      @aes_cipher ||= Encryption::AesCipher.new
    end

    def encrypted_image(image)
      aes_cipher.encrypt(image, key)
    end

    def key
      @key ||= SecureRandom.bytes(32)
    end
  end
end
