require 'rails_helper'

RSpec.describe DelegatedAccess::OpaqueToken do
  describe '.generate' do
    it 'returns a fresh 43-character base64url string without padding' do
      token = described_class.generate

      expect(token).to match(/\A[A-Za-z0-9_-]{43}\z/)
      expect(described_class.generate).not_to eq(token)
    end
  end

  describe '.digest' do
    it 'is the hex SHA-256 of the string' do
      expect(described_class.digest('token')).to eq(Digest::SHA256.hexdigest('token'))
      expect(described_class.digest(nil)).to eq(Digest::SHA256.hexdigest(''))
    end
  end
end
