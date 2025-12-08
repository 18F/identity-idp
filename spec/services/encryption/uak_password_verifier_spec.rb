require 'rails_helper'

RSpec.describe Encryption::UakPasswordVerifier do
  describe Encryption::UakPasswordVerifier::PasswordDigest do
    describe '.parse_from_string' do
      it 'does not blow up with unknown/new keys' do
        digest = Encryption::UakPasswordVerifier.digest('password')
        str = JSON.parse(digest).merge(some_new_field: 'some_new_field').to_json

        digest = Encryption::UakPasswordVerifier::PasswordDigest.parse_from_string(str)
        expect(digest.encrypted_password).to be_present
      end

      it 'raises an encryption error when the password digest is nil' do
        expect do
          Encryption::UakPasswordVerifier::PasswordDigest.parse_from_string(nil)
        end.to raise_error(Encryption::EncryptionError)
      end
    end
  end

  describe '.digest' do
    it 'creates a digest from the password' do
      salt = '1' * 64 # 32 hex encoded bytes is 64 characters
      # The newrelic_rpm gem added a call to `SecureRandom.hex(8)` in
      # abstract_segment.rb on 6/13/18. Our New Relic tracers in
      # config/initializers/new_relic_tracers.rb trigger this call, which
      # is why we stub with a default value first.
      allow(SecureRandom).to receive(:hex) { salt }
      allow(SecureRandom).to receive(:hex).once.with(32).and_return(salt)

      digest = described_class.digest('saltypickles')

      uak = Encryption::UserAccessKey.new(password: 'saltypickles', salt: salt)
      parsed_digest = JSON.parse(digest, symbolize_names: true)
      uak.unlock(parsed_digest[:encryption_key])

      expect(parsed_digest[:encrypted_password]).to eq(uak.encrypted_password)
      expect(parsed_digest[:encryption_key]).to eq(uak.encryption_key)
      expect(parsed_digest[:password_salt]).to eq(salt)
      expect(parsed_digest[:password_cost]).to eq(uak.cost)
    end
  end

  describe '.verify' do
    it 'returns true if the password matches' do
      password = 'saltypickles'

      digest = described_class.digest(password)
      result = described_class.verify(
        password: password,
        digest: digest,
        user_uuid: nil,
        log_context: nil,
      )

      expect(result).to eq(true)
    end

    it 'returns false if the password does not match' do
      digest = described_class.digest('saltypickles')
      result = described_class.verify(
        password: 'pepperpickles',
        digest: digest,
        user_uuid: nil,
        log_context: nil,
      )

      expect(result).to eq(false)
    end

    it 'returns false for nonsese' do
      result = described_class.verify(
        password: 'saltypickles',
        digest: 'this is fake',
        user_uuid: nil,
        log_context: nil,
      )

      expect(result).to eq(false)
    end

    it 'allows verification of a legacy password with a 20 byte salt' do
      # Legacy passwords had 20 bytes salts, which were SHA256 digested to get
      # to a 32 byte salt (64 char hexdigest). This test verifies that the
      # password verifier is capable of properly verifying those passwords
      # using known values.

      password = 'saltypickles'
      legacy_password_digest = {
        encrypted_password: '6bc24a92c215c316d977bbe7beda7067d725992340321d46b122b9701be423d0',
        encryption_key: 'VUl6QFRZeQZ5XUBZalp+BHwBdUljeFhaVANmQmpmdVl8c3paUWhyX2p
          oegBqaFgAeVpfWX5odgNRZFhAVXNEYGJ1SERTdUh2UwNAXmVeU0ZkWURJYVxbAGdnXGhRX
          WpzZXhydmMCfllkaHpGUmZ2W2MDal1pAVhoYnV1BWdoXGVTZVNCVXhUelR3XGZUSmoEZAN
          qSX5bRAZpaF8EUV0FX2R2U0JTd0QDfXhmQ2V4aUdSZmUAUV1mfmdkdnRTZQF0U3dIdVJ1B
          UNVXUhzZGV9R1IBQARqAERGVWVUc1RbfgJjAWphaVsASGR1dkV9d2Z8ZXRTQmpnV0Z/ZVx
          AewAFf2RnQHZ+ZVR/Ul5UZ1JndgNSXH0DZWhqQ2IAdlpjAWlJYWQACXlZR1lUd3ZeeVpfW
          WNddkJrGWIQZV8zXjFfOEY8bnNnfj5wRWZuVRA0MgdafV5RWA=='.gsub(/\s/, ''),
        password_salt: 'u4KDouyiHwPgksKphAp1',
        password_cost: '4000$8$4$',
      }.to_json

      result = described_class.verify(
        password: password,
        digest: legacy_password_digest,
        user_uuid: nil,
        log_context: nil,
      )

      expect(result).to eq(true)
    end
  end
end
