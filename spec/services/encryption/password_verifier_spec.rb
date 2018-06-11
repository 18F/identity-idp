require 'rails_helper'

describe Encryption::PasswordVerifier do
  describe '.digest' do
    it 'creates a digest from the password' do
      salt = '1' * 20
      allow(Devise).to receive(:friendly_token).and_return(salt)

      digest = described_class.digest('saltypickles')

      parsed_digest = JSON.parse(digest)
      uak = Encryption::UserAccessKey.new(password: 'saltypickles', salt: salt)
      uak.unlock(parsed_digest['encryption_key'])

      expect(parsed_digest['encrypted_password']).to eq(uak.encrypted_password)
      expect(parsed_digest['encryption_key']).to eq(uak.encryption_key)
      expect(parsed_digest['password_salt']).to eq(salt)
      expect(parsed_digest['password_cost']).to eq(uak.cost)
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
      password = 'saltypickles'

      digest = described_class.digest('saltypickles')
      result = described_class.verify(password: 'pepperpickles', digest: digest)

      expect(result).to eq(false)
    end
  end
end
