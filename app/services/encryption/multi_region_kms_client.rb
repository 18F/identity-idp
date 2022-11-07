require 'json'
module Encryption
  class MultiRegionKmsClient
    # Lazily-loaded per-region client factory
    KMS_REGION_CLIENT_POOL = Hash.new do |h, region|
      h[region] = ConnectionPool.new(size: IdentityConfig.store.aws_kms_client_multi_pool_size) do
        Aws::KMS::Client.new(
          instance_profile_credentials_timeout: 1, # defaults to 1 second
          instance_profile_credentials_retries: 5, # defaults to 0 retries
          region: region, # The region in which the client is being instantiated
        )
      end
    end

    def initialize
      @aws_client_pools = {}
      # Eager-loaded per-region clients based on current region configs
      IdentityConfig.store.aws_kms_regions.each do |region|
        @aws_client_pools[region] = KMS_REGION_CLIENT_POOL[region]
      end
    end

    # Use each KMS client to encrypt with params and options
    # Region format example: '{"regions": {"us-east-1": "cipher", "us-west-2": "othercipher"}}'
    def encrypt(key_id, plaintext, encryption_context)
      if FeatureManagement.kms_multi_region_enabled?
        encrypt_multi(key_id, plaintext, encryption_context)
      else
        encrypt_legacy(key_id, plaintext, encryption_context)
      end
    end

    def decrypt(ciphertext, encryption_context)
      cipher_data = resolve_decryption(ciphertext)
      cipher_data.region_client_pool.with do |region_client|
        region_client.decrypt(
          ciphertext_blob: cipher_data.resolved_ciphertext,
          encryption_context: encryption_context,
        ).plaintext
      end
    end

    private

    def encrypt_multi(key_id, plaintext, encryption_context)
      region_ciphers = {}
      @aws_client_pools.each do |region, kms_client_pool|
        raw_region_ciphertext = kms_client_pool.with do |kms_client|
          kms_client.encrypt(
            key_id: key_id,
            plaintext: plaintext,
            encryption_context: encryption_context,
          )
        end
        region_ciphers[region] = Base64.strict_encode64(raw_region_ciphertext.ciphertext_blob)
      end
      { regions: region_ciphers }.to_json
    end

    def encrypt_legacy(key_id, plaintext, encryption_context)
      region_client_pool = @aws_client_pools[IdentityConfig.store.aws_region]
      unless region_client_pool
        raise EncryptionError, 'Current region not found in clients for legacy encryption'
      end
      region_client_pool.with do |region_client|
        region_client.encrypt(
          key_id: key_id,
          plaintext: plaintext,
          encryption_context: encryption_context,
        ).ciphertext_blob
      end
    end

    CipherData = RedactedStruct.new(
      :region_client_pool,
      :resolved_ciphertext,
      allowed_members: [:region_client_pool],
    )

    def find_available_region(regions)
      regions.each do |region, cipher|
        region_client_pool = @aws_client_pools[region]
        if region_client_pool
          return CipherData.new(region_client_pool, Base64.strict_decode64(cipher))
        end
      end
      raise EncryptionError, 'No supported region found in ciphertext'
    end

    def resolve_region_decryption(regions)
      # For each region that the ciphertext has a cipher for, check to see if that region is
      # represented in the clients available. Check default region before checking others
      curr_region_client_pool = @aws_client_pools[IdentityConfig.store.aws_region]
      curr_region_cipher = regions[IdentityConfig.store.aws_region]
      if curr_region_cipher && curr_region_client_pool
        CipherData.new(curr_region_client_pool, Base64.strict_decode64(curr_region_cipher))
      else
        find_available_region(regions)
      end
    end

    def resolve_legacy_decryption(ciphertext)
      # Decode the raw ciphertext
      curr_region = IdentityConfig.store.aws_region
      region_client_pool = @aws_client_pools[curr_region]
      resolved_ciphertext = ciphertext
      return CipherData.new(region_client_pool, resolved_ciphertext) if region_client_pool
      raise EncryptionError, "No client found for region #{curr_region}"
    end

    def resolve_decryption(ciphertext)
      # The ciphertext should either be a json HASH keyed by "regions", or a plain string. Start by
      # checking if it looks like the JSON hash we want
      if ciphertext.start_with?('{"regions"')
        parsed_payload = JSON.parse(ciphertext)
        if parsed_payload.is_a?(Hash)
          regions = parsed_payload['regions']
          resolve_region_decryption(regions)
        else
          raise EncryptionError, 'Malformed JSON ciphertext, not a hash'
        end
      else
        resolve_legacy_decryption(ciphertext)
      end
    end
  end
end
