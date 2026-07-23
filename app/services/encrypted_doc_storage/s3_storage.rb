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

    # @param [String] file_path "#{user_uuid}/#{profile.id}/#{file.uuid}"
    # @param [String] encrypted_attempt_events a bundle of events that have been encrypted
    def write_attempt_events(path:, encrypted_attempt_events:)
      key = "attempt_events/#{path}"

      s3_client.put_object(
        bucket:,
        body: encrypted_attempt_events,
        key:,
      )
    end

    # @param [String] file_path "#{user_uuid}/#{profile.id}"
    # @param [String] file_name profile.encrypted_attempts_file_reference
    def retrieve_attempt_object(file_path:, file_name:)
      key = "attempt_events/#{file_path}/#{file_name}"

      s3_client.get_object(
        bucket:,
        key:,
      ).body.read
    end

    def delete_user_attempt_data(user_uuid:)
      key = "attempt_events/#{user_uuid}"

      s3_client.delete_object(bucket:, key:)
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
