require 'rails_helper'

describe Encryption::PasswordVerifier do
  describe '.digest' do
    it 'creates a digest from the password' do
      salt = '1' * 20
      allow(Devise).to receive(:friendly_token).and_return(salt)

      digest = described_class.digest('saltypickles')

      uak = Encryption::UserAccessKey.new(password: 'saltypickles', salt: salt)
      uak.unlock(digest.encryption_key)

      expect(digest.encrypted_password).to eq(uak.encrypted_password)
      expect(digest.encryption_key).to eq(uak.encryption_key)
      expect(digest.password_salt).to eq(salt)
      expect(digest.password_cost).to eq(uak.cost)
    end
  end

  describe '.verify' do
    it 'returns true if the password matches' do
      password = 'saltypickles'

      digest = described_class.digest(password).to_s
      result = described_class.verify(password: password, digest: digest)

      expect(result).to eq(true)
    end

    it 'returns false if the password does not match' do
      digest = described_class.digest('saltypickles').to_s
      result = described_class.verify(password: 'pepperpickles', digest: digest)

      expect(result).to eq(false)
    end

    it 'returns false for nonsese' do
      result = described_class.verify(password: 'saltypickles', digest: 'this is fake')

      expect(result).to eq(false)
    end
  end

  it 'raises an encryption error when the password digest is nil' do
    expect do
      Encryption::PasswordVerifier::PasswordDigest.parse_from_string(nil)
    end.to raise_error(Encryption::EncryptionError)
  end
end
