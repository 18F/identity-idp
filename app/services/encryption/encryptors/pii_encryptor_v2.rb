# frozen_string_literal: true

module Encryption
  module Encryptors
    class PiiEncryptorV2
      VERSION = 1
      CIPHERTEXT_KEY = 't'
      SALT_KEY = 's'
      COMPRESSED_KEY = 'c'
      COST_KEY = 'cost'
      VERSION_KEY = 'v'

      MINIMUM_COMPRESS_LIMIT = 300

      Ciphertext = RedactedStruct.new(
        :encrypted_data,
        :salt,
        :cost,
        :compressed,
        :version,
        allowed_members: [:cost, :compressed, :version]
      ) do
        def self.parse_from_string(ciphertext_string)
          payload = MessagePack.unpack(ciphertext_string)
          ciphertext = payload[CIPHERTEXT_KEY]
          salt = payload[SALT_KEY]
          cost = payload[COST_KEY]
          compressed = payload[COMPRESSED_KEY]
          version = payload[VERSION_KEY]

          new(ciphertext, salt, cost, compressed, version)
        rescue MessagePack::MalformedFormatError
          raise EncryptionError, 'ciphertext is not valid messagepack'
        end

        def to_s
          {
            CIPHERTEXT_KEY => encrypted_data,
            SALT_KEY => salt,
            COST_KEY => cost,
            COMPRESSED_KEY => compressed,
            VERSION_KEY => version,
          }.to_msgpack
        end
      end.freeze

      def initialize(password)
        @password = password
        @aes_cipher = AesCipherV2.new
        @multi_region_kms_client = KmsClientV2.new(
          kms_key_id: IdentityConfig.store.aws_kms_multi_region_key_id,
        )
      end

      def encrypt(plaintext, compress: true, user_uuid: nil)
        salt = SecureRandom.hex(32)
        cost = IdentityConfig.store.scrypt_cost

        plaintext, compress = if compress && should_compress?(plaintext)
                      [Zlib.gzip(plaintext), 1]
                    else
                      [plaintext, 0]
                    end

        aes_encryption_key = scrypt_password_digest(salt: salt, cost: cost)
        aes_encrypted_ciphertext = aes_cipher.encrypt(plaintext, aes_encryption_key)

        multi_region_kms_encrypted_ciphertext = multi_region_kms_client.encrypt(
          aes_encrypted_ciphertext, kms_encryption_context(user_uuid: user_uuid)
        )

        Ciphertext.new(
          multi_region_kms_encrypted_ciphertext, salt, cost, compress, VERSION,
        ).to_s
      end

      def decrypt(ciphertext_string, user_uuid: nil)
        ciphertext = Ciphertext.parse_from_string(ciphertext_string)

        aes_encrypted_ciphertext = multi_region_kms_client.decrypt(
          ciphertext.encrypted_data, kms_encryption_context(user_uuid: user_uuid)
        )
        aes_encryption_key = scrypt_password_digest(salt: ciphertext.salt, cost: ciphertext.cost)
        decrypted = aes_cipher.decrypt(aes_encrypted_ciphertext, aes_encryption_key)
        if ciphertext.compressed == 1
          Zlib.gunzip(decrypted)
        else
          decrypted
        end
      end

      private

      attr_reader :password, :aes_cipher, :multi_region_kms_client

      def kms_encryption_context(user_uuid:)
        {
          'context' => 'pii-encryption',
          'user_uuid' => user_uuid,
        }
      end

      def should_compress?(value)
        value.bytesize >= MINIMUM_COMPRESS_LIMIT
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


# a = Pii::Attributes.new(
#   first_name: 'Test',
#   last_name: 'Testerson',
#   dob: '2023-01-01',
#   zipcode: '10000',
#   phone: '414-414-4144',
#   ssn: '123456789',
# )

# e = Encryption::Encryptors::PiiEncryptor.new('salty pickles')
# e2 = Encryption::Encryptors::PiiEncryptorV2.new('salty pickles')


# old = e.encrypt(a.to_json, user_uuid: 'abc')
# new = e2.encrypt(a.to_json, user_uuid: 'abc')

# new.bytesize / old.bytesize.to_f

# e2.decrypt(new, user_uuid: 'abc')
