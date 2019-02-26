require 'base64'

module Encryption
  class KmsClient # rubocop:disable Metrics/ClassLength
    include Encodable

    KEY_TYPE = {
      KMS: 'KMSc',
      LOCAL_KEY: 'LOCc',
    }.freeze

    def encrypt(plaintext, encryption_context)
      KmsLogger.log(:encrypt, encryption_context)
      return encrypt_kms(plaintext, encryption_context) if FeatureManagement.use_kms?
      encrypt_local(plaintext, encryption_context)
    end

    def decrypt(ciphertext, encryption_context)
      return decrypt_contextless_kms(ciphertext) if self.class.looks_like_contextless?(ciphertext)
      KmsLogger.log(:decrypt, encryption_context)
      return decrypt_kms(ciphertext, encryption_context) if use_kms?(ciphertext)
      decrypt_local(ciphertext, encryption_context)
    end

    def self.looks_like_kms?(ciphertext)
      ciphertext.start_with?(KEY_TYPE[:KMS])
    end

    def self.looks_like_local_key?(ciphertext)
      ciphertext.start_with?(KEY_TYPE[:LOCAL_KEY])
    end

    def self.looks_like_contextless?(ciphertext)
      !looks_like_kms?(ciphertext) && !looks_like_local_key?(ciphertext)
    end

    private

    def use_kms?(ciphertext)
      FeatureManagement.use_kms? && self.class.looks_like_kms?(ciphertext)
    end

    def encrypt_kms(plaintext, encryption_context)
      KEY_TYPE[:KMS] + chunk_plaintext(plaintext).map do |chunk|
        Base64.strict_encode64(
          encrypt_raw_kms(chunk, encryption_context),
        )
      end.to_json
    end

    def encrypt_raw_kms(plaintext, encryption_context)
      raise ArgumentError, 'kms plaintext exceeds 4096 bytes' if plaintext.bytesize > 4096
      aws_client.encrypt(
        key_id: Figaro.env.aws_kms_key_id,
        plaintext: plaintext,
        encryption_context: encryption_context,
      ).ciphertext_blob
    end

    def decrypt_kms(ciphertext, encryption_context)
      clipped_ciphertext = ciphertext.gsub(/\A#{KEY_TYPE[:KMS]}/, '')
      ciphertext_chunks = JSON.parse(clipped_ciphertext)
      ciphertext_chunks.map do |chunk|
        decrypt_raw_kms(
          Base64.strict_decode64(chunk),
          encryption_context,
        )
      end.join('')
    rescue JSON::ParserError, ArgumentError => error
      raise EncryptionError, "Failed to parse KMS ciphertext: #{error}"
    end

    def decrypt_raw_kms(ciphertext, encryption_context)
      aws_client.decrypt(
        ciphertext_blob: ciphertext,
        encryption_context: encryption_context,
      ).plaintext
    rescue Aws::KMS::Errors::InvalidCiphertextException
      raise EncryptionError, 'Aws::KMS::Errors::InvalidCiphertextException'
    end

    def encrypt_local(plaintext, encryption_context)
      KEY_TYPE[:LOCAL_KEY] + chunk_plaintext(plaintext).map do |chunk|
        Base64.strict_encode64(
          encryptor.encrypt(chunk, local_encryption_key(encryption_context)),
        )
      end.to_json
    end

    def decrypt_local(ciphertext, encryption_context)
      clipped_ciphertext = ciphertext.gsub(/\A#{KEY_TYPE[:LOCAL_KEY]}/, '')
      ciphertext_chunks = JSON.parse(clipped_ciphertext)
      ciphertext_chunks.map do |chunk|
        encryptor.decrypt(
          Base64.strict_decode64(chunk),
          local_encryption_key(encryption_context),
        )
      end.join('')
    rescue JSON::ParserError, ArgumentError => error
      raise EncryptionError, "Failed to parse local ciphertext: #{error}"
    end

    def local_encryption_key(encryption_context)
      OpenSSL::HMAC.digest(
        'sha256',
        Figaro.env.password_pepper,
        (encryption_context.keys + encryption_context.values).sort.join(''),
      )
    end

    def decrypt_contextless_kms(ciphertext)
      ContextlessKmsClient.new.decrypt(ciphertext)
    end

    # chunk plaintext into ~4096 byte chunks, but not less than 1024 bytes in a chunk if chunking.
    # we do this by counting how many chunks we have and adding one.
    # :reek:FeatureEnvy
    def chunk_plaintext(plaintext)
      plain_size = plaintext.bytesize
      number_chunks = plain_size / 4096
      chunk_size = plain_size / (1 + number_chunks)
      plaintext.scan(/.{1,#{chunk_size}}/m)
    end

    def aws_client
      @aws_client ||= Aws::KMS::Client.new(
        instance_profile_credentials_timeout: 1, # defaults to 1 second
        instance_profile_credentials_retries: 5, # defaults to 0 retries
      )
    end

    def encryptor
      @encryptor ||= Encryptors::AesEncryptor.new
    end
  end
end
