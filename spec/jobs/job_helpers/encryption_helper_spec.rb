require 'rails_helper'

RSpec.describe JobHelpers::EncryptionHelper do
  subject(:encryption_helper) { JobHelpers::EncryptionHelper.new }

  describe '#decrypt' do
    let(:key) { SecureRandom.random_bytes(32) }
    let(:iv) { SecureRandom.random_bytes(12) }
    let(:plaintext) { 'the quick brown fox jumps over the lazy dog' }

    it 'decrypts data' do
      encrypted = encryption_helper.encrypt(data: plaintext, iv:, key:)

      expect(encryption_helper.decrypt(data: encrypted, iv:, key:)).to eq(plaintext)
    end
  end
end
