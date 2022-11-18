module EncryptedDocumentStorage
  class DocumentWriter
    def encrypt_and_write_document(front_image:, back_image:)
      key = SecureRandom.bytes(32)
      encrypted_front_image = aes_cipher.encrypt(front_image, key)
      encrypted_back_image = aes_cipher.encrypt(back_image, key)

      front_image_uuid = SecureRandom.uuid
      back_image_uiid = SecureRandom.uuid

      storage.write_image(encrypted_image: encrypted_front_image, name: front_image_uuid)
      storage.write_image(encrypted_image: encrypted_back_image, name: back_image_uiid)

      WriteDocumentResult.new(
        front_uuid: front_image_uuid,
        back_uuid: back_image_uiid,
        front_encryption_key: Base64.strict_encode64(key),
        back_encryption_key: Base64.strict_encode64(key),
      )
    end

    def storage
      @storage ||= begin
        if Rails.env.production?
          S3Storage.new
        else
          LocalStorage.new
        end
      end
    end

    def aes_cipher
      @aes_cipher ||= Encryption::AesCipher.new
    end
  end
end
