module IrsAttemptsApi
  class EnvelopeEncryptor
    Result = Struct.new(:filename, :iv, :encrypted_key, :encrypted_data, keyword_init: true)

    # A new key is generated for each encryption.  This key is encrypted with the public_key
    # provided so that only the owner of the private key may decrypt this data.
    def self.encrypt(data:, timestamp:, public_key:)
      compressed_data = Zlib.gzip(data)
      cipher = OpenSSL::Cipher.new('aes-128-cbc')
      cipher.encrypt
      key = cipher.random_key
      iv = cipher.random_iv
      encrypted_data = cipher.update(compressed_data) + cipher.final
      digest = Digest::SHA256.hexdigest(encrypted_data)
      encrypted_key = public_key.public_encrypt(key)
      formatted_time = formatted_timestamp(timestamp)

      filename =
        "FCI-#{IdentityConfig.store.irs_attempt_api_csp_id}_#{formatted_time}_#{digest}.json.gz"

      Result.new(
        filename: filename,
        iv: iv,
        encrypted_key: encrypted_key,
        encrypted_data: encrypted_data,
      )
    end

    def self.formatted_timestamp(timestamp)
      timestamp.strftime('%Y%m%dT%HZ')
    end

    def self.decrypt(encrypted_data:, key:, iv:)
      cipher = OpenSSL::Cipher.new('aes-128-cbc')
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      decrypted = cipher.update(encrypted_data) + cipher.final

      Zlib.gunzip(decrypted)
    end
  end
end
