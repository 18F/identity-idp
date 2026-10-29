# frozen_string_literal: true

module SiteKeys
  # Wraps and unwraps a user's site key root under a user-held secret using the same scrypt +
  # KMS scheme as profile PII.
  class RootCipher
    def initialize(user)
      @user = user
    end

    def wrap(root, secret)
      encryptor(secret).encrypt(Base64.strict_encode64(root), user_uuid: user.uuid)
    end

    # @raise [RootMismatchError] when the wrap does not authenticate under the secret
    # @raise [Encryption::EncryptionError] for any other failure, which may be transient
    def unwrap(encrypted_root, secret)
      Base64.strict_decode64(encryptor(secret).decrypt(encrypted_root, user_uuid: user.uuid))
    rescue Encryption::DecipherError => err
      raise RootMismatchError, err.message
    rescue ArgumentError, TypeError, NoMethodError => err
      raise Encryption::EncryptionError, "site key root is malformed: #{err.class}"
    end

    private

    attr_reader :user

    def encryptor(secret)
      Encryption::Encryptors::PiiEncryptor.new(secret)
    end
  end
end
