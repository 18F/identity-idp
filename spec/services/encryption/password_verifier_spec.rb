require 'rails_helper'

describe Encryption::PasswordVerifier do
  let(:password) { 'saltypickles' }
  let(:user_uuid) { 'asdf-1234' }

  describe Encryption::PasswordVerifier::PasswordDigest do
    describe '.parse_from_string' do
      it 'does not blow up with unknown/new keys' do
        str = {
          encrypted_password: 'encrypted_password',
          encryption_key: 'encryption_key',
          password_salt: 'password_salt',
          password_cost: 'password_cost',
          some_new_field: 'some_new_field',
        }.to_json

        digest = Encryption::PasswordVerifier::PasswordDigest.parse_from_string(str)
        expect(digest.encrypted_password).to eq('encrypted_password')
      end
    end
  end

  describe '#digest' do
    it 'creates a digest from the password' do
      salt = '1' * 64 # 32 hex encoded bytes is 64 characters
      # The newrelic_rpm gem added a call to `SecureRandom.hex(8)` in
      # abstract_segment.rb on 6/13/18. Our New Relic tracers in
      # config/initializers/new_relic_tracers.rb trigger this call, which
      # is why we stub with a default value first.
      allow(SecureRandom).to receive(:hex) { salt }
      allow(SecureRandom).to receive(:hex).once.with(32).and_return(salt)

      scrypt_salt = IdentityConfig.store.scrypt_cost + OpenSSL::Digest::SHA256.hexdigest(salt)
      scrypt_password = double(SCrypt::Password, digest: 'scrypted_password')
      encoded_scrypt_password = Base64.strict_encode64('scrypted_password')

      expect(SCrypt::Engine).to receive(:hash_secret).
        with(password, scrypt_salt, 32).
        and_return('scrypted')
      expect(SCrypt::Password).to receive(:new).with('scrypted').and_return(scrypt_password)

      kms_client = Encryption::KmsClient.new
      expect(kms_client).to receive(:encrypt).with(
        encoded_scrypt_password,
        { 'user_uuid' => user_uuid, 'context' => 'password-digest' },
      ).and_return('kms_ciphertext')
      expect(Encryption::KmsClient).to receive(:new).and_return(kms_client)

      result = subject.digest(password: password, user_uuid: user_uuid)

      expect(JSON.parse(result, symbolize_names: true)).to eq(
        password_salt: salt,
        password_cost: IdentityConfig.store.scrypt_cost,
        encrypted_password: 'kms_ciphertext',
      )
    end
  end

  describe '#verify' do
    it 'returns true if the password does match' do
      digest = subject.digest(password: password, user_uuid: user_uuid)

      result = subject.verify(digest: digest, password: password, user_uuid: user_uuid)

      expect(result).to eq(true)
    end

    it 'returns false if the password does not match' do
      digest = subject.digest(password: password, user_uuid: user_uuid)

      result = subject.verify(digest: digest, password: 'qwerty', user_uuid: user_uuid)

      expect(result).to eq(false)
    end

    it 'returns false for nonsense' do
      result = subject.verify(
        digest: 'nonsense',
        password: password,
        user_uuid: user_uuid,
      )

      expect(result).to eq(false)
    end

    it 'allows verification of legacy UAK passwords' do
      legacy_digest = Encryption::UakPasswordVerifier.digest(password)

      good_match_result = subject.verify(
        digest: legacy_digest,
        password: password,
        user_uuid: user_uuid,
      )

      expect(good_match_result).to eq(true)

      bad_match_result = subject.verify(
        digest: legacy_digest,
        password: 'fake news',
        user_uuid: user_uuid,
      )

      expect(bad_match_result).to eq(false)
    end
  end

  describe '#stale_digest?' do
    it 'returns true if the digest is stale' do
      digest = Encryption::UakPasswordVerifier.digest(password)

      result = subject.stale_digest?(digest)

      expect(result).to eq(true)
    end

    it 'returns false if the digest is fresh' do
      digest = subject.digest(password: password, user_uuid: user_uuid)

      result = subject.stale_digest?(digest)

      expect(result).to eq(false)
    end
  end
end
