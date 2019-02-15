require 'rails_helper'

describe Encryption::UakPasswordVerifier do
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
      result = described_class.verify(password: password, digest: digest)

      expect(result).to eq(true)
    end

    it 'returns false if the password does not match' do
      digest = described_class.digest('saltypickles')
      result = described_class.verify(password: 'pepperpickles', digest: digest)

      expect(result).to eq(false)
    end

    it 'returns false for nonsese' do
      result = described_class.verify(password: 'saltypickles', digest: 'this is fake')

      expect(result).to eq(false)
    end

    it 'allows verification of a legacy password with a 20 byte salt' do
      # Legacy passwords had 20 bytes salts, which were SHA256 digested to get
      # to a 32 byte salt (64 char hexdigest). This test verifies that the
      # password verifier is capable of properly verifying those passwords
      # using known values.

      password = 'saltypickles'
      legacy_password_digest = {
        encrypted_password: '6245274034d8d4dcc2d9930b431c4356aeaac9c7d0b7e2148ac19dcd12dfbc7a',
        encryption_key: 'VUl6QFRZeQZ5XnZofXhTBGN3WABqdGZnamZTR30CeVl8c3paUWhyX2p
        oegBqaFgAeVpfWWReZnhjd2pHZV1AX3wAQH1nW1hKY1t+BGd4agFnaF8AZFxASmd1SAV/ZXV
        Kal1IUX50WAV7AFRpZ15hR1J4WANlZXZKZAB6BGYACQJSdURkYV1HA2JdanJRAFMEZQB+dGY
        BVH5nWlhJZQNyflJnfgFqA2VJUV1IQ35dampVZVxbUwFmZWRZCWhSd0RyYwBEempnXFxmW3p
        8UQJ+An10XGJ/eGphU1kJY1FdZgJmaHpaZF5pSWV3XH5hZUhbfEp5SWp4cgRlZGpZY2ZUemV
        bBXhnaFRqfgBDBGZnREN/aFx4fnZbR1J0aQJmZ0ABVEoACXlZR1lUd3ZeeVpfWX54VF10Gg0
        KZGA/XSt2L2YCbGMHYjNzXFBtDCUwMgdafV5RWA=='.gsub(/\s/, ''),
        password_salt: 'u4KDouyiHwPgksKphAp1',
        password_cost: '4000$8$4$',
      }.to_json

      result = described_class.verify(password: password, digest: legacy_password_digest)

      expect(result).to eq(true)
    end
  end

  it 'raises an encryption error when the password digest is nil' do
    expect do
      Encryption::UakPasswordVerifier::PasswordDigest.parse_from_string(nil)
    end.to raise_error(Encryption::EncryptionError)
  end
end
