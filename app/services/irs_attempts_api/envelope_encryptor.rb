require 'base16'

module IrsAttemptsApi
  class EnvelopeEncryptor
    Result = Struct.new(:filename, :iv, :encrypted_key, :encrypted_data, keyword_init: true)

    @timer = {}

    def self.timestamp(name)
      @timer[name] = Time.zone.now
      if @previous_timer
        elapsed = (@timer[name] - @timer[@previous_timer]).to_f
        puts "#{elapsed} sec. from '#{@previous_timer}' to '#{name}'"
      end
      @previous_timer = name
    end

    # A new key is generated for each encryption.  This key is encrypted with the public_key
    # provided so that only the owner of the private key may decrypt this data.
    def self.encrypt(data:, timestamp:, public_key_str:)
      timestamp(:start)
      # gzip -- fixing this is probably our biggest win.
      compressed_data = Zlib.gzip(data)
      timestamp(:ruby_compression)

      timestamp(:file_write)
      Dir.mktmpdir do |dir|
        f = File.new('asdf.txt', 'w')
        puts "File: #{f.path}"
        f.write(data)
        `gzip #{f.path}`
        timestamp(:gzip_shell)
      end

      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      timestamp(:cipher_generation)

      cipher.encrypt
      timestamp(:cipher_dot_encrypt)

      key = cipher.random_key
      iv = cipher.random_iv
      timestamp(:get_and_iv_assignment)

      public_key = OpenSSL::PKey::RSA.new(Base64.strict_decode64(public_key_str))
      timestamp(:pub_key_generation)

      encrypted_data = cipher.update(compressed_data) + cipher.final
      timestamp(:data_encryption)

      encoded_data = Base16.encode16(encrypted_data)
      timestamp(:base16_encoding)

      file = File.new('base16_me.txt', 'wb')
      file.write(encrypted_data)
      file.close
      timestamp(:large_file_write)
      `xxd -p -c 0 base16_me.txt > base16_done.txt`
      timestamp(:xxd)

      digest = Digest::SHA256.hexdigest(encoded_data)
      timestamp(:sha256)

      encrypted_key = public_key.public_encrypt(key)
      timestamp(:pub_key_encryption)
      formatted_time = formatted_timestamp(timestamp)

      filename =
        "FCI-Logingov_#{formatted_time}_#{digest}.dat.gz.hex"

      Result.new(
        filename: filename,
        iv: iv,
        encrypted_key: encrypted_key,
        encrypted_data: encoded_data,
      )
    end

    def self.formatted_timestamp(timestamp)
      timestamp.strftime('%Y%m%dT%HZ')
    end

    def self.decrypt(encrypted_data:, key:, iv:)
      cipher = OpenSSL::Cipher.new('aes-256-cbc')
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      decrypted = cipher.update(Base16.decode16(encrypted_data)) + cipher.final

      Zlib.gunzip(decrypted)
    end
  end
end
