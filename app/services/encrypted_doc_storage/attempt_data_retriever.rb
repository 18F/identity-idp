# frozen_string_literal: true

module EncryptedDocStorage
  class AttemptDataRetriever
    def initialize(s3_enabled: false)
      @s3_enabled = s3_enabled
    end

    def retrieve_user_proofing_events(file_path:, file_name:)
      storage.retrieve_attempt_object(file_path:, file_name:)
    end

    private

    def storage
      @storage ||= @s3_enabled ? S3Storage.new : LocalStorage.new
    end
  end
end
