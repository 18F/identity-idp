module AwsKmsClientHelper
  # The real ConnectionPools persist clients across specs which
  # makes stubbing via the Aws.config unreliable
  class FakeConnectionPool
    def initialize(**options)
      @options = options
    end

    def with
      yield Aws::KMS::Client.new(**@options)
    end
  end

  def stub_aws_kms_client(random_key = random_str, ciphered_key = random_str)
    aws_key_id = IdentityConfig.store.aws_kms_key_id
    Aws.config[:kms] = {
      stub_responses: {
        encrypt: { ciphertext_blob: ciphered_key, key_id: aws_key_id },
        decrypt: { plaintext: random_key, key_id: aws_key_id },
      },
    }
    [random_key, ciphered_key]
  end

  # Configs is an array of:
  # [{ ciphertext:, plaintext:, key_id:, region: }]
  def stub_mapped_aws_kms_client(configs)
    encryptor = proc do |context|
      config = configs.find do |c|
        c.slice(:key_id, :plaintext) == context.params.slice(:key_id, :plaintext) &&
          c[:region] == context.client.config.region
      end
      { ciphertext_blob: config[:ciphertext], key_id: config[:key_id] }
    end

    decryptor = proc do |context|
      config = configs.find do |c|
        c[:ciphertext] == context.params[:ciphertext_blob]
      end
      { plaintext: config[:plaintext], key_id: config[:key_id] }
    end

    Aws.config[:kms] = {
      stub_responses: {
        encrypt: encryptor,
        decrypt: decryptor,
      },
    }
  end

  def stub_aws_kms_client_invalid_ciphertext(ciphered_key = random_str)
    aws_key_id = IdentityConfig.store.aws_kms_key_id
    Aws.config[:kms] = {
      stub_responses: {
        encrypt: { ciphertext_blob: ciphered_key, key_id: aws_key_id },
        decrypt: 'InvalidCiphertextException',
      },
    }
  end

  def random_str
    SecureRandom.random_bytes(32)
  end
end
