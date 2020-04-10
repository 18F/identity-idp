module Encryption
  PiiCiphertext = Struct.new(:encrypted_data, :salt, :cost) do
    include Encodable
    class << self
      include Encodable
    end

    def self.parse_from_string(ciphertext_string)
      parsed_json = JSON.parse(ciphertext_string)
      new(extract_encrypted_data(parsed_json), parsed_json['salt'], parsed_json['cost'])
    rescue JSON::ParserError
      raise EncryptionError, 'ciphertext is not valid JSON'
    end

    def to_s
      {
        encrypted_data: encode(encrypted_data),
        salt: salt,
        cost: cost,
      }.to_json
    end

    def self.extract_encrypted_data(parsed_json)
      encoded_encrypted_data = parsed_json['encrypted_data']
      raise EncryptionError, 'ciphertext invalid' unless valid_base64_encoding?(
        encoded_encrypted_data,
      )
      decode(encoded_encrypted_data)
    end
  end
end
