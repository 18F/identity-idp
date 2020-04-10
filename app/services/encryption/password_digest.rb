module Encryption
  PasswordDigest = Struct.new(
    :encrypted_password,
    :encryption_key,
    :password_salt,
    :password_cost,
    keyword_init: true,
  ) do
    def self.parse_from_string(digest_string)
      data = JSON.parse(digest_string, symbolize_names: true)
      new(data)
    rescue JSON::ParserError, TypeError, ArgumentError
      raise EncryptionError, 'digest contains invalid json'
    end

    def to_s
      {
        encrypted_password: encrypted_password,
        password_salt: password_salt,
        password_cost: password_cost,
      }.to_json
    end

    def uak_password_digest?
      encryption_key.present?
    end
  end
end
