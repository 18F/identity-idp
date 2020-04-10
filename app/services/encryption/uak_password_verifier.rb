module Encryption
  class UakPasswordVerifier
    def self.digest(password)
      salt = SecureRandom.hex(32)
      uak = UserAccessKey.new(password: password, salt: salt)
      uak.build
      UakPasswordDigest.new(
        uak.encrypted_password,
        uak.encryption_key,
        salt,
        uak.cost,
      ).to_s
    end

    def self.verify(password:, digest:)
      return false if password.blank?
      parsed_digest = UakPasswordDigest.parse_from_string(digest)
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
