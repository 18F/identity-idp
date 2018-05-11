require 'rails_helper'
# NOTE this set of specs intentionally includes lots of
# duplicated code in order to explicitly show the algorithm at work.

describe 'NIST Encryption Model' do
# Generate and store a 128-bit salt S.
# Z1, Z2 = scrypt(S, password)   # split 256-bit output into two halves
# Generate random R.
# D = KMS_GCM_Encrypt(key=server_secret, plaintext=R) ^ Z1
# E = hash( Z2 + R )
# F = hash(E)
# C = GCM_Encrypt(key = E, plaintext=PII)  #occurs outside AWS-KMS
# Store F in password file, and store C and D.
#
# To decrypt PII and to verify passwords:
# Compute Z1’, Z2’ = scrypt(S, password’)
# R’ = KMS_GCM_Decrypt(key=server_secret, ciphertext=(D ^ Z1*)).
# E’ = hash( Z2’ + R’)
# F’ = hash(E’)
# Check to see if F’ matches the entry in the password file; if so, allow the login.
# plaintext_PII = GCM_Decrypt(key=E’, ciphertext = C)

  before do
    allow(FeatureManagement).to receive(:use_kms?).and_return(true)
  end

  let(:kms_prefix) { '{}cH' } # XOR of 'KMSx' and '0000'

  describe 'password hashing' do
    it 'creates two substrings Z1 and Z2 via scrypt of password and salt' do
      # Generate and store a 128-bit salt S.
      ## (ours is actually 256 bits)
      password = 'a long sekrit'
      salt = SecureRandom.random_bytes(32)

      # Z1, Z2 = scrypt(S, password)   # split 256-bit output into two halves
      user_access_key = Encryption::UserAccessKey.new(password: password, salt: salt)

      expect(hex_to_bin(user_access_key.z1).length).to eq 16
      expect(hex_to_bin(user_access_key.z2).length).to eq 16

      expect { SCrypt::Password.new(user_access_key.as_scrypt_hash) }.
        to_not raise_error
    end
  end

  describe 'KMS encryption of random R' do
    it 'creates encrypted key D and hash E' do
      random_R, ciphered_R = stub_aws_kms_client
      allow(SecureRandom).to receive(:random_bytes).and_return(random_R)

      password = 'a long sekrit'
      salt = '1' * 32
      user_access_key = Encryption::UserAccessKey.new(password: password, salt: salt)

      # D = KMS_GCM_Encrypt(key=server_secret, plaintext=R) ^ Z1
      # E = hash( Z2 + R )
      encrypted_D = xor(ciphered_R, user_access_key.z1)
      hash_E = OpenSSL::Digest::SHA256.hexdigest(user_access_key.z2 + random_R)

      user_access_key.build

      expect(user_access_key.masked_ciphertext).to eq(kms_prefix + encrypted_D)
      expect(user_access_key.cek).to eq hash_E
    end
  end

  describe 'password storage and login' do
    it 'creates hash F of Z2 using auto-generated salt' do
      random_R, ciphered_R = stub_aws_kms_client
      allow(SecureRandom).to receive(:random_bytes).and_return(random_R)

      password = 'a long sekrit'
      user = create(:user, password: password)

      expect(user.valid_password?(password)).to eq true
      expect(user.user_access_key).to be_a Encryption::UserAccessKey
      expect(user.user_access_key.random_r).to eq random_R
      expect(user.encryption_key).to_not be_nil
      expect(user.password_salt).to_not be_nil

      hash_E = OpenSSL::Digest::SHA256.hexdigest(user.user_access_key.z2 + random_R)
      hash_F = OpenSSL::Digest::SHA256.hexdigest(user.user_access_key.cek)

      expect(user.encrypted_password).to eq hash_F
      expect(user.user_access_key.cek).to eq hash_E
      expect(user.user_access_key.encrypted_password).to eq hash_F

      user.user_access_key.unlock(user.encryption_key)
      expect(user.user_access_key.cek).to eq(hash_E)

      encrypted_D = Base64.strict_decode64(user.encryption_key)

      expect(kms_prefix + xor(user.user_access_key.z1, ciphered_R)).to eq(encrypted_D)
    end
  end

  describe 'PII encryption' do
    it 'creates encrypted payload C with KMS-encrypted key D using local AES cipher' do
      random_R, ciphered_R = stub_aws_kms_client
      allow(SecureRandom).to receive(:random_bytes).and_return(random_R)

      password = 'a long sekrit'
      salt = '1' * 32
      user_access_key = Encryption::UserAccessKey.new(password: password, salt: salt)
      pii = 'some sensitive stuff'

      # D = KMS_GCM_Encrypt(key=server_secret, plaintext=R) ^ Z1
      # E = hash( Z2 + R )
      # C = GCM_Encrypt(key = E, plaintext=PII)  # occurs outside AWS-KMS
      # Store C and D.
      encrypted_D = xor(user_access_key.z1, ciphered_R)
      hash_E = OpenSSL::Digest::SHA256.hexdigest(user_access_key.z2 + random_R)

      password_encryptor = Pii::PasswordEncryptor.new
      encrypted_payload = password_encryptor.encrypt(pii, user_access_key)

      expect(encrypted_payload).to_not match(pii)

      # encrypted_payload is an envelope that contains C and D.
      encrypted_key, encrypted_C = open_envelope(encrypted_payload)

      expect(Base64.strict_decode64(encrypted_key)).to eq(kms_prefix + encrypted_D)

      # unroll encrypted_C to verify it was encrypted with hash_E
      cipher = Pii::Cipher.new

      expect { cipher.decrypt(encrypted_C, hash_E) }.not_to raise_error

      deciphered = cipher.decrypt(encrypted_C, hash_E)
      deciphered_pii, deciphered_pii_fingerprint = open_envelope(deciphered)

      expect(deciphered_pii).to eq pii

      fingerprint = Pii::Fingerprinter.fingerprint(deciphered_pii)
      expect(fingerprint).to eq deciphered_pii_fingerprint
    end
  end

  def open_envelope(envelope)
    envelope.split(Pii::Encryptor::DELIMITER).map { |segment| Base64.strict_decode64(segment) }
  end

  def hex_to_bin(str)
    str.scan(/../).map(&:hex).pack('c*')
  end

  def xor(left, right)
    left_unpacked = left.unpack('C*')
    right_unpacked = right.unpack('C*')
    left_unpacked.zip(right_unpacked).map do |left_byte, right_byte|
      left_byte ^ right_byte
    end.pack('C*')
  end
end
