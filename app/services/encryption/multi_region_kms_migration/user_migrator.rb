# frozen_string_literal: true

module Encryption
  module MultiRegionKmsMigration
    class UserMigrator
      include ::NewRelic::Agent::MethodTracer

      attr_reader :user

      def initialize(user)
        @user = user
      end

      def migrate!
        user.with_lock do
          if needs_password_migration?
            multi_region_digest = migrate_ciphertext(user.encrypted_password_digest)
            user.update!(
              encrypted_password_digest: user.encrypted_password_digest,
              encrypted_password_digest_multi_region: multi_region_digest,
            )
          end

          if needs_recovery_code_migration?
            multi_region_digest = migrate_ciphertext(user.encrypted_recovery_code_digest)
            user.update!(
              encrypted_recovery_code_digest: user.encrypted_recovery_code_digest,
              encrypted_recovery_code_digest_multi_region: multi_region_digest,
            )
          end
        end
      end

      private

      def migrate_ciphertext(ciphertext_string)
        ciphertext = Encryption::PasswordVerifier::PasswordDigest.parse_from_string(
          ciphertext_string,
        )
        kms_decrypted_password_digest = multi_region_kms_client.decrypt(
          ciphertext.encrypted_password, kms_encryption_context
        )
        multi_region_kms_encrypted_password = multi_region_kms_client.encrypt(
          kms_decrypted_password_digest, kms_encryption_context
        )
        Encryption::PasswordVerifier::PasswordDigest.new(
          encrypted_password: multi_region_kms_encrypted_password,
          password_salt: ciphertext.password_salt,
          password_cost: ciphertext.password_cost,
        ).to_s
      end

      def needs_password_migration?
        return false if user.encrypted_password_digest_multi_region.present?
        return false if user.encrypted_password_digest.blank?

        ciphertext = Encryption::PasswordVerifier::PasswordDigest.parse_from_string(
          user.encrypted_password_digest,
        )

        return false if ciphertext.uak_password_digest?
        true
      end

      def needs_recovery_code_migration?
        return false if user.encrypted_recovery_code_digest_multi_region.present?
        return false if user.encrypted_recovery_code_digest.blank?

        ciphertext = Encryption::PasswordVerifier::PasswordDigest.parse_from_string(
          user.encrypted_recovery_code_digest,
        )

        return false if ciphertext.uak_password_digest?
        true
      end

      def kms_encryption_context
        {
          'context' => 'password-digest',
          'user_uuid' => user.uuid,
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
