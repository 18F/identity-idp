require 'json'
module Encryption
  class MultiRegionKMSClient
    def initialize
      @aws_clients = Hash.new
      # Instantiate an array of aws clients based on the provided regions in the environment
      JSON.parse(Figaro.env.aws_kms_regions).each do | region |
        @aws_clients[region] = Aws::KMS::Client.new(
          instance_profile_credentials_timeout: 1, # defaults to 1 second
          instance_profile_credentials_retries: 5, # defaults to 0 retries
          region: region, # The region in which the client is being instantiated
        )
      end
    end

    # Use each KMS client to encrypt with params and options
    # Region format example: '{"reg": {"us-east-1": "cipher", "us-west-2": "othercipher"}}'
    def encrypt(key_id, plaintext, encryption_context)
      region_ciphers = {}
      @aws_clients.each do |region, kms_client|
        r_cipher = kms_client.encrypt(key_id: key_id,
                                      plaintext: plaintext,
                                      encryption_context: encryption_context)
        region_ciphers[region] = r_cipher.ciphertext_blob
      end
      { reg: region_ciphers }.to_json
    end

    def decrypt(ciphertext, encryption_context)
      # The client that will be used to decode the ciphertext, the ciphertext after being parsed out of whatever
      # format it's in
      region_client, resolved_ciphertext = resolve_decryption(ciphertext)

      # If the ciphertext is valid and there's a relevant client, try to actually decode it
      region_client.decrypt(
        ciphertext_blob: resolved_ciphertext,
        encryption_context: encryption_context).plaintext
    end

    private

    def resolve_decryption(ciphertext)
      # The ciphertext should either be a json HASH keyed by "reg", or a plain string. Start by checking if it looks
      # like the JSON hash we want
      if ciphertext.start_with?('{"reg"')
        parsed_ciphertext = JSON.parse(ciphertext)
        unless parsed_ciphertext.is_a?(Hash)
          raise EncryptionError, 'Malformed JSON ciphertext, not a hash'
        end
        # It's a hash, make sure that it has the "reg" key. If not, this is a strange malformed key error
        regions = parsed_ciphertext['reg']
        if parsed_ciphertext.length == 1 and regions
          # For each region that the ciphertext has a cipher for, check to see if that region is represented
          # in the clients available
          regions.each do |region, cipher|
            region_client = @aws_clients[region]
            resolved_ciphertext = cipher
            return region_client, resolved_ciphertext if region_client
          end
        end
        raise EncryptionError, 'No supported region found in ciphertext'
      else
        # Decode the raw ciphertext
        curr_region = Figaro.env.aws_region
        region_client = @aws_clients[curr_region]
        resolved_ciphertext = ciphertext
        return region_client, resolved_ciphertext if region_client
        raise EncryptionError, "No client found for region #{curr_region}"
      end
    end
  end
end
