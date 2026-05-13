# frozen_string_literal: true

module EncryptedDocStorage
  class S3Storage
    def write_image(encrypted_image:, name:)
      s3_client.put_object(
        bucket:,
        body: encrypted_image,
        key: name,
      )
    end

    def write_attempt_events(path:, encrypted_attempt_events:)
      # TODO: Make attempt_events/ directory in s3 escrow bucket
      # TODO: Make directory readable from application
      s3_client.put_object(
        bucket:,
        body: encrypted_attempt_events,
        key: path,
      )
    end

    def retrieve_attempt_object(file_path:, file_name:)
      full_path = "#{file_path}/#{file_name}"

      s3_client.get_object(
        bucket:,
        key: full_path,
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

    def bucket
      IdentityConfig.store.encrypted_document_storage_s3_bucket
    end
  end
end
