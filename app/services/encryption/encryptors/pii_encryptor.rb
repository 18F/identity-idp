# frozen_string_literal: true

module Encryption
  module Encryptors
    class PiiEncryptor
      include ::NewRelic::Agent::MethodTracer

      Digest = RedactedStruct.new(
        :encrypted_data,
        :aes_encrypted_ciphertext,
        :user_kms_encryption_context,
        :kms_client,
        :salt,
        :cost,
        keyword_init: true,
        allowed_members: [:cost],
      ) do
        include Encodable
        class << self
          include Encodable
        end

        def self.parse_from_string(ciphertext_string)
          parsed_json = JSON.parse(ciphertext_string)
          new(
            encrypted_data: extract_encrypted_data(parsed_json),
            salt: parsed_json['salt'],
            cost: parsed_json['cost'],
          )
        rescue JSON::ParserError
          raise EncryptionError, 'ciphertext is not valid JSON'
        end

        def encrypt_data!
          self[:encrypted_data] =
            kms_client.encrypt(aes_encrypted_ciphertext, user_kms_encryption_context)
          nil
        end

        def to_s
          {
            encrypted_data: encode(encrypted_data),
            salt: salt,
            cost: cost,
          }.to_json
        end

        def self.extract_encrypted_data(parsed_json)
          encoded_encrypted_data = parsed_json['encrypted_data']
          raise EncryptionError, 'ciphertext invalid' unless valid_base64_encoding?(
            encoded_encrypted_data,
          )
          decode(encoded_encrypted_data)
        end
      end.freeze

      def initialize(password)
        @password = password
        @aes_cipher = AesCipher.new
        @single_region_kms_client = KmsClient.new(
          kms_key_id: IdentityConfig.store.aws_kms_key_id,
        )
        @multi_region_kms_client = KmsClient.new(
          kms_key_id: IdentityConfig.store.aws_kms_multi_region_key_id,
        )
      end

      def encrypt(plaintext, user_uuid: nil)
        salt = SecureRandom.hex(32)
        cost = IdentityConfig.store.scrypt_cost
        aes_encryption_key = scrypt_password_digest(salt: salt, cost: cost)
        aes_encrypted_ciphertext = aes_cipher.encrypt(plaintext, aes_encryption_key)
        user_kms_encryption_context = kms_encryption_context(user_uuid: user_uuid)
        single_region_encrypted_value = Digest.new(
          kms_client: single_region_kms_client,
          aes_encrypted_ciphertext:,
          user_kms_encryption_context:,
          salt:,
          cost:,
        )
        single_region_encrypted_value.encrypt_data!

        multi_region_encrypted_value = Digest.new(
          kms_client: multi_region_kms_client,
          aes_encrypted_ciphertext:,
          user_kms_encryption_context:,
          salt:,
          cost:,
        )
        multi_region_encrypted_value.encrypt_data!

        RegionalEncryptedValuePair.new(
          single_region_encrypted_value:,
          multi_region_encrypted_value:,
        )
      end

      def decrypt(digest_pair, user_uuid: nil)
        ciphertext_string = digest_pair.multi_or_single_region_encrypted_value.to_s
        ciphertext = Digest.parse_from_string(ciphertext_string)
        aes_encrypted_ciphertext = multi_region_kms_client.decrypt(
          ciphertext.encrypted_data, kms_encryption_context(user_uuid: user_uuid)
        )
        aes_encryption_key = scrypt_password_digest(salt: ciphertext.salt, cost: ciphertext.cost)
        aes_cipher.decrypt(aes_encrypted_ciphertext, aes_encryption_key)
      end

      private

      attr_reader :password, :aes_cipher, :single_region_kms_client, :multi_region_kms_client

      def kms_encryption_context(user_uuid:)
        {
          'context' => 'pii-encryption',
          'user_uuid' => user_uuid,
        }
      end

      def scrypt_password_digest(salt:, cost:)
        scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
        scrypted = SCrypt::Engine.hash_secret password, scrypt_salt, 32
        scrypt_password_digest = SCrypt::Password.new(scrypted).digest
        [scrypt_password_digest].pack('H*')
      end

      add_method_tracer :encrypt, "Custom/#{name}/encrypt"
      add_method_tracer :decrypt, "Custom/#{name}/decrypt"
    end
  end
end
