module EncryptedDocumentStorage
  class DocumentWriter
    def encrypt_and_write_document(front_image:, back_image:)
      key = SecureRandom.bytes(32)
      encrypted_front_image = aes_cipher.encrypt(front_image, key)
      encrypted_back_image = aes_cipher.encrypt(back_image, key)

      front_image_reference = SecureRandom.uuid
      back_image_reference = SecureRandom.uuid

      storage.write_image(encrypted_image: encrypted_front_image, reference: front_image_reference)
      storage.write_image(encrypted_image: encrypted_back_image, reference: back_image_reference)

      WriteDocumentResult.new(
        front_reference: front_image_reference,
        back_reference: back_image_reference,
        encryption_key: Base64.strict_encode64(key),
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
