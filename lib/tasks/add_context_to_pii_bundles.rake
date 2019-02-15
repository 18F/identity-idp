namespace :adhoc do
  desc 'Add KMS encryption context to existing PII bundles'
  task add_context_to_pii_bundles: :environment do
    Rails.logger = Logger.new(STDOUT)

    @kms_client = Encryption::KmsClient.new

    batch_count = 0
    # rubocop:disable Metrics/MethodLength
    def add_context_to_encrypted_pii(encrypted_pii, user_uuid)
      ciphertext = Encryption::Encryptors::PiiEncryptor::Ciphertext.parse_from_string(
        encrypted_pii,
      )
      return unless @kms_client.class.looks_like_contextless?(ciphertext.encrypted_data)
      ciphertext.encrypted_data = @kms_client.encrypt(
        @kms_client.decrypt(
          ciphertext.encrypted_data,
          'context' => 'pii-encryption',
          'user_uuid' => user_uuid,
        ),
        'context' => 'pii-encryption',
        'user_uuid' => user_uuid,
      )
      ciphertext.to_s
    end
    # rubocop:enable Metrics/MethodLength

    Profile.includes(:user).find_in_batches do |batch|
      Rails.logger.info "Processing batch #{batch_count += 1}"
      batch.each do |profile|
        updated_pii = add_context_to_encrypted_pii(profile.encrypted_pii, profile.user.uuid)
        profile.encrypted_pii = updated_pii if updated_pii.present?
        updated_recovery_pii = add_context_to_encrypted_pii(
          profile.encrypted_pii_recovery, profile.user.uuid
        )
        profile.encrypted_pii_recovery = updated_recovery_pii if updated_recovery_pii.present?
        profile.save! if profile.changed?
      end
      sleep 1
    end
    Rails.logger.info('Done!')
  end
end
