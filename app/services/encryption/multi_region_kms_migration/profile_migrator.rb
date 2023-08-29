module Encryption
  module MultiRegionKmsMigration
    class ProfileMigrator
      include ::NewRelic::Agent::MethodTracer

      attr_reader :profile

      def initialize(profile)
        @profile = profile
      end

      def migrate!
        if profile.encrypted_pii.blank? || profile.encrypted_pii_recovery.blank?
          raise "Profile##{profile.id} is missing encrypted_pii or or encrypted_pii_recovery"
        end

        return if profile.encrypted_pii_multi_region.present? ||
                  profile.encrypted_pii_recovery_multi_region.present?

        encrypted_pii_multi_region = migrate_ciphertext(profile.encrypted_pii)
        encrypted_pii_recovery_multi_region = migrate_ciphertext(profile.encrypted_pii_recovery)
        profile.update!(
          encrypted_pii: profile.encrypted_pii,
          encrypted_pii_multi_region: encrypted_pii_multi_region,
          encrypted_pii_recovery: profile.encrypted_pii_recovery,
          encrypted_pii_recovery_multi_region: encrypted_pii_recovery_multi_region,
        )
      end

      private

      def migrate_ciphertext(ciphertext_string)
        ciphertext = Encryption::Encryptors::PiiEncryptor::Ciphertext.parse_from_string(
          ciphertext_string,
        )
        aes_encrypted_data = multi_region_kms_client.decrypt(
          ciphertext.encrypted_data, kms_encryption_context
        )
        multi_region_kms_encrypted_data = multi_region_kms_client.encrypt(
          aes_encrypted_data, kms_encryption_context
        )
        Encryption::Encryptors::PiiEncryptor::Ciphertext.new(
          multi_region_kms_encrypted_data,
          ciphertext.salt,
          ciphertext.cost,
        )
      end

      def kms_encryption_context
        {
          'context' => 'pii-encryption',
          'user_uuid' => profile.user.uuid,
        }
      end

      def multi_region_kms_client
        @multi_region_kms_client ||= KmsClient.new(
          kms_key_id: IdentityConfig.store.aws_kms_multi_region_key_id,
        )
      end

      add_method_tracer :migrate!, "Custom/#{name}/migrate!"
    end
  end
end
