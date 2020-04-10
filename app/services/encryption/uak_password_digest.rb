module Encryption
  UakPasswordDigest = Struct.new(
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
end
