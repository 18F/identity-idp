module EncryptedDocumentStorage
  class S3Storage
    def write_document(encrypted_document:, reference:)
      s3_client.put_object(
        bucket: 'TODO-use-a-real-bucket',
        body: encrypted_document,
        key: reference,
      )
    end

    private

    def s3_client
      Aws::S3::Client.new(
        http_open_timeout: 5,
        http_read_timeout: 5,
        compute_checksums: false,
      )
    end
  end
end
