module Encryption
  class MultiRegionKMSClient
    RegionClient = Struct.new(:region, :client, :key_id, keyword_init: true)

    def initialize
      @region_client_configs = {}
      # Instantiate an array of aws clients based on the provided regions in the environment
      # Example expected config:
      #   [{"region": "us-north-1", "key_id": "abc"}, {"region": "us-south-1", "key_id": "def"}]
      JSON.parse(Figaro.env.aws_kms_region_configs).each do |region_config|
        region = region_config['region']
        key_id = region_config['key_id']

        client = Aws::KMS::Client.new(
          instance_profile_credentials_timeout: 1, # defaults to 1 second
          instance_profile_credentials_retries: 5, # defaults to 0 retries
          region: region, # The region in which the client is being instantiated
        )

        region_client_configs[region] = RegionClient.new(
          region: region,
          client: client,
          key_id: key_id,
        )
      end
    end

    # Use each KMS client to encrypt with params and options
    # Region format example: '{"regions": {"us-east-1": "cipher", "us-west-2": "othercipher"}}'
    def encrypt(key_id, plaintext, encryption_context)
      if FeatureManagement.kms_multi_region_enabled?
        encrypt_multi(plaintext, encryption_context)
      else
        encrypt_legacy(key_id, plaintext, encryption_context)
      end
    end

    def decrypt(ciphertext, encryption_context)
      cipher_data = resolve_decryption(ciphertext)
      cipher_data.region_client.client.decrypt(
        ciphertext_blob: cipher_data.resolved_ciphertext,
        encryption_context: encryption_context,
      ).plaintext
    end

    private

    attr_reader :region_client_configs

    def encrypt_multi(plaintext, encryption_context)
      region_ciphers = region_client_configs.map do |region, region_client|
        raw_region_ciphertext = region_client.client.encrypt(key_id: region_client.key_id,
                                                             plaintext: plaintext,
                                                             encryption_context: encryption_context)
        [region, Base64.strict_encode64(raw_region_ciphertext.ciphertext_blob)]
      end.to_h

      { regions: region_ciphers }.to_json
    end

    def encrypt_legacy(key_id, plaintext, encryption_context)
      region_client = region_client_configs[Figaro.env.aws_region]
      unless region_client
        raise EncryptionError, 'Current region not found in clients for legacy encryption'
      end
      region_client.client.encrypt(key_id: key_id,
                                   plaintext: plaintext,
                                   encryption_context: encryption_context).ciphertext_blob
    end

    CipherData = Struct.new(:region_client, :resolved_ciphertext)

    def find_available_region(regions)
      regions.each do |region, cipher|
        region_client = region_client_configs[region]
        return CipherData.new(region_client, Base64.strict_decode64(cipher)) if region_client
      end
      raise EncryptionError, 'No supported region found in ciphertext'
    end

    def resolve_region_decryption(regions)
      # For each region that the ciphertext has a cipher for, check to see if that region is
      # represented in the clients available. Check default region before checking others
      curr_region_client = region_client_configs[Figaro.env.aws_region]
      curr_region_cipher = regions[Figaro.env.aws_region]
      if curr_region_cipher && curr_region_client
        CipherData.new(curr_region_client, Base64.strict_decode64(curr_region_cipher))
      else
        find_available_region(regions)
      end
    end

    def resolve_legacy_decryption(ciphertext)
      # Decode the raw ciphertext
      curr_region = Figaro.env.aws_region
      region_client = region_client_configs[curr_region]
      resolved_ciphertext = ciphertext
      return CipherData.new(region_client, resolved_ciphertext) if region_client
      raise EncryptionError, "No client found for region #{curr_region}"
    end

    def resolve_decryption(ciphertext)
      # The ciphertext should either be a json HASH keyed by "regions", or a plain string. Start by
      # checking if it looks like the JSON hash we want
      if ciphertext.start_with?('{"regions"')
        parsed_payload = JSON.parse(ciphertext)
        if parsed_payload.is_a?(Hash) # rubocop:disable Style/GuardClause
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
