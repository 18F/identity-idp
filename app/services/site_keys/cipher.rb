# frozen_string_literal: true

module SiteKeys
  # Wraps and unwraps a person's site key under a secret the person holds, with the scrypt and
  # KMS scheme that protects verified profile attributes.
  class Cipher
    def initialize(user)
      @user = user
    end

    def wrap(private_key, secret)
      encryptor(secret).encrypt(Base64.strict_encode64(private_key), user_uuid: user.uuid)
    end

    # @raise [MismatchError] when the wrap does not authenticate under the secret
    # @raise [Encryption::EncryptionError] for any other failure, which may be transient
    def unwrap(encrypted_private_key, secret)
      Base64.strict_decode64(encryptor(secret).decrypt(encrypted_private_key, user_uuid: user.uuid))
    rescue Encryption::DecipherError => err
      raise MismatchError, err.message
    rescue ArgumentError, TypeError, NoMethodError => err
      raise Encryption::EncryptionError, "site key wrap is malformed: #{err.class}"
    end

    private

    attr_reader :user

    def encryptor(secret)
      Encryption::Encryptors::PiiEncryptor.new(secret)
    end
  end
end
