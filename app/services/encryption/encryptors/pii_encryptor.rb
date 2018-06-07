module Encryption
  module Encryptors
    class PiiEncryptor
      Ciphertext = Struct.new(:encrypted_data, :salt, :cost) do
        include Pii::Encodable
        class << self
          include Pii::Encodable
        end

        def self.parse_from_string(ciphertext_string)
          parsed_json = JSON.parse(ciphertext_string)
          encoded_encrypted_data = parsed_json['encrypted_data']
          raise Pii::EncryptionError, 'ciphertext invalid' unless valid_base64_encoding?(
            encoded_encrypted_data
          )
          new(decode(encoded_encrypted_data), parsed_json['salt'], parsed_json['cost'])
        rescue JSON::ParserError
          raise Pii::EncryptionError, 'ciphertext is not valid JSON'
        end

        def to_s
          {
            encrypted_data: encode(encrypted_data),
            salt: salt,
            cost: cost,
          }.to_json
        end
      end

      def initialize(password)
        @password = password
        @aes_cipher = Pii::Cipher.new
        @kms_client = KmsClient.new
      end

      def encrypt(plaintext)
        salt = Devise.friendly_token[0, 20]
        cost = Figaro.env.scrypt_cost
        aes_encryption_key = scrypt_password_digest(salt: salt, cost: cost)
        aes_encrypted_ciphertext = aes_cipher.encrypt(plaintext, aes_encryption_key)
        kms_encrypted_ciphertext = kms_client.encrypt(aes_encrypted_ciphertext)
        Ciphertext.new(kms_encrypted_ciphertext, salt, cost).to_s
      end

      def decrypt(ciphertext_string)
        ciphertext = Ciphertext.parse_from_string(ciphertext_string)
        aes_encrypted_ciphertext = kms_client.decrypt(ciphertext.encrypted_data)
        aes_encryption_key = scrypt_password_digest(salt: ciphertext.salt, cost: ciphertext.cost)
        aes_cipher.decrypt(aes_encrypted_ciphertext, aes_encryption_key)
      end

      private

      attr_reader :password, :aes_cipher, :kms_client

      def scrypt_password_digest(salt:, cost:)
        scrypt_salt = cost + OpenSSL::Digest::SHA256.hexdigest(salt)
        scrypted = SCrypt::Engine.hash_secret password, scrypt_salt, 32
        scrypt_password_digest = SCrypt::Password.new(scrypted).digest
        scrypt_password_digest[0...32]
      end
    end
  end
end
