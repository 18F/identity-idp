module Encryption
  module Encryptors
    class EccPiiEncryptor
      Ciphertext = RedactedStruct.new(:encrypted_data, :ephemeral_public_key) do
        include Encodable
        class << self
          include Encodable
        end

        def self.parse_from_string(ciphertext_string)
          parsed_json = JSON.parse(ciphertext_string)
          new(
            extract_encrypted_data(parsed_json),
            extract_ephemeral_public_key(parsed_json),
          )
        rescue JSON::ParserError
          raise EncryptionError, 'ciphertext is not valid JSON'
        end

        def to_s
          {
            encrypted_data: encode(encrypted_data),
            ephemeral_public_key: encode(ephemeral_public_key.public_to_der),
          }.to_json
        end

        def self.extract_encrypted_data(parsed_json)
          encoded_encrypted_data = parsed_json['encrypted_data']
          raise EncryptionError, 'ciphertext invalid' unless valid_base64_encoding?(
            encoded_encrypted_data,
          )
          decode(encoded_encrypted_data)
        end

        def self.extract_ephemeral_public_key(parsed_json)
          encoded_public_key = parsed_json['ephemeral_public_key']
          raise EncryptionError, 'ciphertext invalid' unless valid_base64_encoding?(
            encoded_public_key,
          )
          OpenSSL::PKey::EC.new(decode(encoded_public_key))
        end
      end

      include Encodable

      attr_reader :aes_cipher, :kms_client

      def initialize
        @aes_cipher = AesCipherV2.new
        @kms_client = KmsClient.new
      end

      def encrypt(plaintext, encoded_user_public_key)
        user_public_key = OpenSSL::PKey::EC.new(
          Base64.strict_decode64(encoded_user_public_key),
        )
        ephemeral_key = OpenSSL::PKey::EC.generate('secp384r1')
        aes_encryption_key = ephemeral_key.dh_compute_key(user_public_key.public_key)
        aes_encrypted_ciphertext = aes_cipher.encrypt(plaintext, aes_encryption_key)
        Ciphertext.new(aes_encrypted_ciphertext, ephemeral_key).to_s
      end

      def decrypt(ciphertext_string, encrypted_user_private_key, password, user_uuid: nil)
        ciphertext = Ciphertext.parse_from_string(ciphertext_string)
        user_private_key = UserPrivateKeyEncryptor.new(password).decrypt(
          encrypted_user_private_key,
          user_uuid: user_uuid,
        )
        aes_encryption_key = user_private_key.dh_compute_key(
          ciphertext.ephemeral_public_key.public_key,
        )
        aes_cipher.decrypt(ciphertext.encrypted_data, aes_encryption_key)
      end
    end
  end
end
