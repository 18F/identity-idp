# frozen_string_literal: true

module EncryptedDocStorage
  class AttemptDataHandler
    def initialize(s3_enabled: false)
      @s3_enabled = s3_enabled
    end

    def retrieve_user_proofing_events(file_path:, file_name:)
      storage.retrieve_attempt_object(file_path:, file_name:)
    end

    def delete_all_user_attempt_data(file_path:)
      storage.delete_user_attempt_data(file_path:)
    end

    private

    def storage
      @storage ||= @s3_enabled ? S3Storage.new : LocalStorage.new
    end
  end
end
