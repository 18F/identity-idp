module EncryptedDocumentStorage
  class S3Storage
    def write_image(encrypted_image:, name:)
      # TODO: Use a configurable bucket name here
      s3_client.put_object(
        bucket: IdentityConfig.store.encrypted_document_storage_s3_bucket,
        body: encrypted_image,
        key: name,
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
