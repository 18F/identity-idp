# :reek:DataClump
module Encryption
  class PasswordVerifier
    PasswordDigest = Struct.new(
      :encrypted_password,
      :encryption_key,
      :password_salt,
      :password_cost,
      keyword_init: true,
    ) do
      def self.parse_from_string(digest_string)
        data = JSON.parse(digest_string, symbolize_names: true)
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
    end

    def initialize
      @aes_cipher = AesCipher.new
      @kms_client = KmsClient.new
    end

    def digest(password:, user_uuid:)
      salt = SecureRandom.hex(32)
      cost = Figaro.env.scrypt_cost
      encrypted_password = encrypt_password(
        password: password, user_uuid: user_uuid, salt: salt, cost: cost,
      )
      PasswordDigest.new(
        encrypted_password: encrypted_password, password_salt: salt, password_cost: cost,
      ).to_s
    end

    def verify(password:, digest:, user_uuid:)
      password_digest = PasswordDigest.parse_from_string(digest)
      return verify_uak_digest(password, digest) if stale_digest?(digest)

      verify_password_against_digest(
        password: password,
        password_digest: password_digest,
        user_uuid: user_uuid,
      )
    rescue EncryptionError
      false
    end

    # :reek:UtilityFunction
    def stale_digest?(digest)
      PasswordDigest.parse_from_string(digest).uak_password_digest?
    end

    private

    attr_reader :kms_client, :aes_cipher

    def encrypt_password(salt:, cost:, password:, user_uuid:)
      scrypted_password = scrypt_password_digest(salt: salt, cost: cost, password: password)
      kms_client.encrypt(
        scrypted_password, kms_encryption_context(user_uuid: user_uuid)
      )
    end

    # :reek:FeatureEnvy
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
      kms_client.decrypt(
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

    def verify_uak_digest(password, digest)
      UakPasswordVerifier.verify(password: password, digest: digest)
    end
  end
end
