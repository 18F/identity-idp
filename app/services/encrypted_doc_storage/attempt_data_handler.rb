# frozen_string_literal: true

module EncryptedDocStorage
  class AttemptDataHandler
    def initialize(s3_enabled: false)
      @s3_enabled = s3_enabled
    end

    # @param [String] file_path "#{user_uuid}/#{profile.id}""
    # @param [String] file_name profile.encrypted_attempts_file_reference
    def retrieve_user_proofing_events(file_path:, file_name:)
      storage.retrieve_attempt_object(file_path:, file_name:)
    end

    # @param [String] user_uuid
    def delete_all_user_attempt_data(user_uuid:)
      storage.delete_user_attempt_data(user_uuid:)
    end

    private

    def storage
      @storage ||= @s3_enabled ? S3Storage.new : LocalStorage.new
    end
  end
end
