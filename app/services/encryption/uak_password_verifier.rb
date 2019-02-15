module Encryption
  class UakPasswordVerifier
    PasswordDigest = Struct.new(
      :encrypted_password,
      :encryption_key,
      :password_salt,
      :password_cost,
    ) do
      def self.parse_from_string(digest_string)
        data = JSON.parse(digest_string, symbolize_names: true)
        new(
          data[:encrypted_password],
          data[:encryption_key],
          data[:password_salt],
          data[:password_cost],
        )
      rescue JSON::ParserError, TypeError
        raise EncryptionError, 'digest contains invalid json'
      end

      def to_s
        {
          encrypted_password: encrypted_password,
          encryption_key: encryption_key,
          password_salt: password_salt,
          password_cost: password_cost,
        }.to_json
      end
    end

    def self.digest(password)
      salt = SecureRandom.hex(32)
      uak = UserAccessKey.new(password: password, salt: salt)
      uak.build
      PasswordDigest.new(
        uak.encrypted_password,
        uak.encryption_key,
        salt,
        uak.cost,
      ).to_s
    end

    def self.verify(password:, digest:)
      return false if password.blank?
      parsed_digest = PasswordDigest.parse_from_string(digest)
      uak = UserAccessKey.new(password: password,
                              salt: parsed_digest.password_salt,
                              cost: parsed_digest.password_cost)
      uak.unlock(parsed_digest.encryption_key)
      Devise.secure_compare(uak.encrypted_password, parsed_digest.encrypted_password)
    rescue EncryptionError
      false
    end
  end
end
