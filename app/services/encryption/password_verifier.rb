# frozen_string_literal: true

module Encryption
  class PasswordVerifier
    include ::NewRelic::Agent::MethodTracer

    PasswordDigest = RedactedStruct.new(
      :encrypted_password,
      :encryption_key,
      :password_salt,
      :password_cost,
      keyword_init: true,
    ) do
      def self.parse_from_string(digest_string)
        data = JSON.parse(digest_string, symbolize_names: true).slice(*members)
        new(data)
      rescue JSON::ParserError, TypeError, ArgumentError
        raise EncryptionError, 'digest contains invalid json'
      end

      def to_s
        {
          encrypted_password: encrypted_password,
          password_salt: password_salt,
          password_cost: password_cost,
        }.to_json
      end

      def uak_password_digest?
        encryption_key.present?
      end
    end.freeze

    def initialize
      @aes_cipher = AesCipher.new
      @single_region_kms_client = KmsClient.new(
        kms_key_id: IdentityConfig.store.aws_kms_key_id,
      )
      @multi_region_kms_client = KmsClient.new(
        kms_key_id: IdentityConfig.store.aws_kms_multi_region_key_id,
      )
    end

    def create_digest(password:, user_uuid:)
      salt = SecureRandom.hex(32)
      cost = IdentityConfig.store.scrypt_cost
      scrypted_password = scrypt_password_digest(salt: salt, cost: cost, password: password)

      multi_region_encrypted_password = multi_region_kms_client.encrypt(
        scrypted_password, kms_encryption_context(user_uuid: user_uuid)
      )
      PasswordDigest.new(
        encrypted_password: multi_region_encrypted_password,
        password_salt: salt,
        password_cost: cost,
      ).to_s
    end

    def create_single_region_digest(password:, user_uuid:)
      salt = SecureRandom.hex(32)
      cost = IdentityConfig.store.scrypt_cost
      scrypted_password = scrypt_password_digest(salt: salt, cost: cost, password: password)

      single_region_encrypted_password = single_region_kms_client.encrypt(
        scrypted_password, kms_encryption_context(user_uuid: user_uuid)
      )
      PasswordDigest.new(
        encrypted_password: single_region_encrypted_password,
        password_salt: salt,
        password_cost: cost,
      ).to_s
    end

    def verify(password:, digest_pair:, user_uuid:, log_context:)
      digest = digest_pair.multi_or_single_region_ciphertext
      password_digest = PasswordDigest.parse_from_string(digest)
      if password_digest.uak_password_digest?
        return verify_uak_digest(password, digest, user_uuid, log_context)
      end

      verify_password_against_digest(
        password: password,
        password_digest: password_digest,
        user_uuid: user_uuid,
      )
    rescue EncryptionError
      false
    end

    def stale_digest?(digest)
      return false if digest.blank?
      PasswordDigest.parse_from_string(digest).uak_password_digest?
    end

    private

    attr_reader :single_region_kms_client, :multi_region_kms_client, :aes_cipher

    def verify_password_against_digest(password:, password_digest:, user_uuid:)
      scrypted_password = scrypt_password_digest(
        password: password,
        salt: password_digest.password_salt,
        cost: password_digest.password_cost,
      )
      decrypted_kms_digest = decrypt_digest_with_kms(password_digest.encrypted_password, user_uuid)
      Devise.secure_compare(scrypted_password, decrypted_kms_digest)
    end

    def decrypt_digest_with_kms(encrypted_password, user_uuid)
      multi_region_kms_client.decrypt(
        encrypted_password, kms_encryption_context(user_uuid: user_uuid)
      )
    end

    def scrypt_password_digest(password:, salt:, cost:)
      scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
      scrypted = SCrypt::Engine.hash_secret password, scrypt_salt, 32
      scrypt_password_digest = SCrypt::Password.new(scrypted).digest
      Base64.strict_encode64(scrypt_password_digest)
    end

    def kms_encryption_context(user_uuid:)
      {
        'context' => 'password-digest',
        'user_uuid' => user_uuid,
      }
    end

    def verify_uak_digest(password, digest, user_uuid, log_context)
      UakPasswordVerifier.verify(
        password: password,
        digest: digest,
        user_uuid: user_uuid,
        log_context: log_context,
      )
    end

    add_method_tracer :create_digest, "Custom/#{name}/create_digest"
    add_method_tracer :verify, "Custom/#{name}/verify"
  end
end
