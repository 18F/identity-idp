module Encryption
  module Encryptors
    class PiiEncryptor
      include ::NewRelic::Agent::MethodTracer

      Ciphertext = RedactedStruct.new(:encrypted_data, :salt, :cost, allowed_members: [:cost]) do
        include Encodable
        class << self
          include Encodable
        end

        def self.parse_from_string(ciphertext_string)
          parsed_json = JSON.parse(ciphertext_string)
          new(extract_encrypted_data(parsed_json), parsed_json['salt'], parsed_json['cost'])
        rescue JSON::ParserError
          raise EncryptionError, 'ciphertext is not valid JSON'
        end

        def to_s
          {
            encrypted_data: encode(encrypted_data),
            salt:,
            cost:,
          }.to_json
        end

        def self.extract_encrypted_data(parsed_json)
          encoded_encrypted_data = parsed_json['encrypted_data']
          raise EncryptionError, 'ciphertext invalid' unless valid_base64_encoding?(
            encoded_encrypted_data,
          )
          decode(encoded_encrypted_data)
        end
      end

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
        aes_encryption_key = scrypt_password_digest(salt:, cost:)
        aes_encrypted_ciphertext = aes_cipher.encrypt(plaintext, aes_encryption_key)
        single_region_kms_encrypted_ciphertext = single_region_kms_client.encrypt(
          aes_encrypted_ciphertext, kms_encryption_context(user_uuid:)
        )
        single_region_ciphertext = Ciphertext.new(
          single_region_kms_encrypted_ciphertext, salt, cost
        ).to_s

        multi_region_kms_encrypted_ciphertext = multi_region_kms_client.encrypt(
          aes_encrypted_ciphertext, kms_encryption_context(user_uuid:)
        )
        multi_region_ciphertext = Ciphertext.new(
          multi_region_kms_encrypted_ciphertext, salt, cost
        ).to_s

        RegionalCiphertextPair.new(
          single_region_ciphertext:,
          multi_region_ciphertext:,
        )
      end

      def decrypt(ciphertext_pair, user_uuid: nil)
        ciphertext_string = ciphertext_pair.multi_or_single_region_ciphertext
        ciphertext = Ciphertext.parse_from_string(ciphertext_string)
        aes_encrypted_ciphertext = multi_region_kms_client.decrypt(
          ciphertext.encrypted_data, kms_encryption_context(user_uuid:)
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
