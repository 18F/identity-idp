# frozen_string_literal: true

require 'base64'

module Encryption
  class KmsClientV2
    include ::NewRelic::Agent::MethodTracer

    LOCAL_KEY_PREFIX = 'LOCcv2'
    LOCAL_KEY_REGEX = /\A#{LOCAL_KEY_PREFIX}/

    def encrypt(plaintext, encryption_context)
      KmsLogger.log(:encrypt, encryption_context)
      return encrypt_kms(plaintext, encryption_context) if FeatureManagement.use_kms?
      encrypt_local(plaintext, encryption_context)
    end

    def decrypt(ciphertext, encryption_context)
      KmsLogger.log(:decrypt, encryption_context)
      return decrypt_kms(ciphertext, encryption_context) if use_kms?(ciphertext)
      decrypt_local(ciphertext, encryption_context)
    end

    def self.looks_like_local_key?(ciphertext)
      ciphertext.start_with?(LOCAL_KEY_PREFIX)
    end

    private

    def use_kms?(ciphertext)
      FeatureManagement.use_kms? && !self.class.looks_local_key?(ciphertext)
    end

    def encrypt_kms(plaintext, encryption_context)
      chunk_plaintext(plaintext).map do |chunk|
        encrypt_raw_kms(chunk, encryption_context)
      end.to_msgpack
    end

    def encrypt_raw_kms(plaintext, encryption_context)
      raise ArgumentError, 'kms plaintext exceeds 4096 bytes' if plaintext.bytesize > 4096
      multi_aws_client.encrypt(IdentityConfig.store.aws_kms_key_id, plaintext, encryption_context)
    end

    def decrypt_kms(ciphertext, encryption_context)
      ciphertext_chunks = MessagePack.unpack(ciphertext)
      decrypted = String.new

      ciphertext_chunks.each do |chunk|
        decrypted << decrypt_raw_kms(
          chunk,
          encryption_context,
        )
      end

      decrypted
    rescue MessagePack::MalformedFormatError, ArgumentError => error
      raise EncryptionError, "Failed to parse KMS ciphertext: #{error}"
    end

    def decrypt_raw_kms(ciphertext, encryption_context)
      multi_aws_client.decrypt(ciphertext, encryption_context)
    rescue Aws::KMS::Errors::InvalidCiphertextException
      raise EncryptionError, 'Aws::KMS::Errors::InvalidCiphertextException'
    end

    def encrypt_local(plaintext, encryption_context)
      LOCAL_KEY_PREFIX + chunk_plaintext(plaintext).map do |chunk|
        encryptor.encrypt(chunk, local_encryption_key(encryption_context))
      end.to_msgpack
    end

    def decrypt_local(ciphertext, encryption_context)
      clipped_ciphertext = ciphertext.gsub(LOCAL_KEY_REGEX, '')
      ciphertext_chunks = MessagePack.unpack(clipped_ciphertext)
      decrypted = String.new
      ciphertext_chunks.each do |chunk|
        decrypted << encryptor.decrypt(
          chunk,
          local_encryption_key(encryption_context),
        )
      end
    rescue MessagePack::MalformedFormatError, ArgumentError => error
      raise EncryptionError, "Failed to parse local ciphertext: #{error}"
    end

    def local_encryption_key(encryption_context)
      OpenSSL::HMAC.digest(
        'sha256',
        IdentityConfig.store.password_pepper,
        (encryption_context.keys + encryption_context.values).sort.join(''),
      )
    end

    # chunk plaintext into ~4096 byte chunks, but not less than 1024 bytes in a chunk if chunking.
    # we do this by counting how many chunks we have and adding one.
    def chunk_plaintext(plaintext)
      plain_size = plaintext.bytesize
      number_chunks = plain_size / 4096
      chunk_size = plain_size / (1 + number_chunks)
      plaintext.scan(/.{1,#{chunk_size}}/m)
    end

    def encryptor
      @encryptor ||= Encryptors::AesEncryptorV2.new
    end

    def multi_aws_client
      @multi_aws_client ||= MultiRegionKmsClient.new
    end

    add_method_tracer :decrypt, "Custom/#{name}/decrypt"
    add_method_tracer :encrypt, "Custom/#{name}/encrypt"
  end
end
