module EncryptedDocumentStorage
  class DocumentWriter
    def encrypt_and_write_document(
      front_image:,
      front_image_content_type:,
      back_image:,
      back_image_content_type:
    )
      key = SecureRandom.bytes(32)
      encrypted_front_image = aes_cipher.encrypt(front_image, key)
      encrypted_back_image = aes_cipher.encrypt(back_image, key)

      front_filename = build_filename_for_content_type(front_image_content_type)
      back_filename = build_filename_for_content_type(back_image_content_type)

      storage.write_image(encrypted_image: encrypted_front_image, name: front_filename)
      storage.write_image(encrypted_image: encrypted_back_image, name: back_filename)

      WriteDocumentResult.new(
        front_filename: front_filename,
        back_filename: back_filename,
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

    # @return {String} A new, unique S3 key for an image of the given content type.
    def build_filename_for_content_type(content_type)
      ext = Rack::Mime::MIME_TYPES.rassoc(content_type)&.first
      "#{SecureRandom.uuid}#{ext}"
    end
  end
end
