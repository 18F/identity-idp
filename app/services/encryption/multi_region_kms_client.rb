require 'json'
module Encryption
  class MultiRegionKMSClient
    def initialize
      @aws_clients = {}
      # Instantiate an array of aws clients based on the provided regions in the environment
      JSON.parse(Figaro.env.aws_kms_regions).each do |region|
        @aws_clients[region] = Aws::KMS::Client.new(
          instance_profile_credentials_timeout: 1, # defaults to 1 second
          instance_profile_credentials_retries: 5, # defaults to 0 retries
          region: region, # The region in which the client is being instantiated
        )
      end
    end

    # Use each KMS client to encrypt with params and options
    # Region format example: '{"regions": {"us-east-1": "cipher", "us-west-2": "othercipher"}}'
    def encrypt(key_id, plaintext, encryption_context)
      region_ciphers = {}
      @aws_clients.each do |region, kms_client|
        r_cipher = kms_client.encrypt(key_id: key_id,
                                      plaintext: plaintext,
                                      encryption_context: encryption_context)
        region_ciphers[region] = r_cipher.ciphertext_blob
      end
      { regions: region_ciphers }.to_json
    end

    def decrypt(ciphertext, encryption_context)
      region_client, resolved_ciphertext = resolve_decryption(ciphertext)
      region_client.decrypt(
        ciphertext_blob: resolved_ciphertext,
        encryption_context: encryption_context,
      ).plaintext
    end

    private

    def resolve_region_decryption(regions)
      # For each region that the ciphertext has a cipher for, check to see if that region is
      # represented in the clients available. Check default region before checking others
      curr_region_client = @aws_clients[Figaro.env.aws_region]
      curr_region_cipher = regions[Figaro.env.aws_region]
      return curr_region_client, curr_region_cipher if curr_region_client && curr_region_cipher
      regions.each do |region, cipher|
        region_client = @aws_clients[region]
        resolved_ciphertext = cipher
        return region_client, resolved_ciphertext if region_client
      end
      raise EncryptionError, 'No supported region found in ciphertext'
    end

    def resolve_legacy_decryption(ciphertext)
      # Decode the raw ciphertext
      curr_region = Figaro.env.aws_region
      region_client = @aws_clients[curr_region]
      resolved_ciphertext = ciphertext
      return region_client, resolved_ciphertext if region_client
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
      else resolve_legacy_decryption(ciphertext)
      end
    end
  end
end
