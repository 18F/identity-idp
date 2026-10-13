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

    # Opens the root with a recovery code or a personal key. A transient failure on one wrap does
    # not stop the other from being tried.
    # @return [String, nil] the root, or nil when the code opens neither wrap
    def recover(record, code)
      secret = RecoveryCode.normalize(code)
      return if secret.nil?

      begin
        root = try_unwrap(record.encrypted_root_recovery_code, secret)
      rescue Encryption::EncryptionError => err
        transient_error = err
      end
      root ||= try_unwrap(record.encrypted_root_personal_key, secret)
      raise transient_error if root.nil? && transient_error
      root
    end

    def try_unwrap(encrypted_root, secret)
      return if encrypted_root.blank? || secret.blank?

      unwrap(encrypted_root, secret)
    rescue RootMismatchError
      nil
    end

    private

    attr_reader :user

    def encryptor(secret)
      Encryption::Encryptors::PiiEncryptor.new(secret)
    end
  end
end
