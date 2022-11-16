module EncryptedDocumentStorage
  class DocumentWriter
    def encrypt_and_write_document(front_image:, back_image:)
      # TODO: Encrypt and write the document
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
  end
end
