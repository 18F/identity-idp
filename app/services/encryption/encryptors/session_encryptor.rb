module Encryption
  module Encryptors
    class SessionEncryptor
      def encrypt(plaintext)
        user_access_key = self.class.load_or_init_user_access_key
        UserAccessKeyEncryptor.new(user_access_key).encrypt(plaintext)
      end

      def decrypt(ciphertext)
        user_access_key = self.class.load_or_init_user_access_key
        UserAccessKeyEncryptor.new(user_access_key).decrypt(ciphertext)
      end

      def self.load_or_init_user_access_key
        if @user_access_key_scrypt_hash.present?
          return UserAccessKey.new(scrypt_hash: @user_access_key_scrypt_hash)
        end

        key = Figaro.env.session_encryption_key
        user_access_key = UserAccessKey.new(password: key, salt: key)
        @user_access_key_scrypt_hash = user_access_key.as_scrypt_hash
        user_access_key
      end
    end
  end
end
