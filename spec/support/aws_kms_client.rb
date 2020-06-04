module AwsKmsClientHelper
  def stub_aws_kms_client(random_key = random_str, ciphered_key = random_str)
    aws_key_id = Figaro.env.aws_kms_key_id
    Aws.config[:kms] = {
      stub_responses: {
        encrypt: { ciphertext_blob: ciphered_key, key_id: aws_key_id },
        decrypt: { plaintext: random_key, key_id: aws_key_id },
      },
    }
    [random_key, ciphered_key]
  end

  def stub_mapped_aws_kms_client(forward = {})
    reverse = forward.invert
    aws_key_id = Figaro.env.aws_kms_key_id
    Aws.config[:kms] = {
      stub_responses: {
        encrypt: lambda { |context|
          { ciphertext_blob: forward[context.params[:plaintext]], key_id: aws_key_id }
        },
        decrypt: lambda { |context|
          { plaintext: reverse[context.params[:ciphertext_blob]], key_id: aws_key_id }
        },
      },
    }
  end

  def stub_aws_kms_client_invalid_ciphertext(ciphered_key = random_str)
    aws_key_id = Figaro.env.aws_kms_key_id
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
