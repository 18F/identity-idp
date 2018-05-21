module Encryption
  module Encryptors
    class UserAccessKeyEncryptor
      include Pii::Encodable

      DELIMITER = '.'.freeze

      def initialize(user_access_key)
        @user_access_key = user_access_key
        @encryptor = Pii::Encryptor.new
      end

      def encrypt(plaintext)
        user_access_key.build unless user_access_key.built?
        encrypted_contents = encryptor.encrypt(plaintext, user_access_key.cek)
        build_ciphertext(user_access_key.encryption_key, encrypted_contents)
      end

      def decrypt(ciphertext)
        encryption_key = encryption_key_from_ciphertext(ciphertext)
        encrypted_contents = encrypted_contents_from_ciphertext(ciphertext)
        unlock_user_access_key(encryption_key)
        encryptor.decrypt(encrypted_contents, user_access_key.cek)
      end

      private

      attr_reader :encryptor, :user_access_key

      def build_ciphertext(encryption_key, encrypted_contents)
        [
          encode(encryption_key),
          encrypted_contents,
        ].join(DELIMITER)
      end

      def encryption_key_from_ciphertext(ciphertext)
        encoded_encryption_key = ciphertext.split(DELIMITER).first
        raise Pii::EncryptionError, 'ciphertext is invalid' unless valid_base64_encoding?(
          encoded_encryption_key
        )
        decode(encoded_encryption_key)
      end

      def encrypted_contents_from_ciphertext(ciphertext)
        contents = ciphertext.split(DELIMITER).second
        raise Pii::EncryptionError, 'ciphertext is missing encrypted contents' if contents.nil?
        contents
      end

      def unlock_user_access_key(encryption_key)
        return if user_access_key.unlocked? && user_access_key.encryption_key == encryption_key
        user_access_key.unlock(encryption_key)
      end
    end
  end
end
