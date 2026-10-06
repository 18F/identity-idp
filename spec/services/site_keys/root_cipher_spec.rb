require 'rails_helper'

RSpec.describe SiteKeys::RootCipher do
  let(:user) { create(:user) }
  let(:root) { SecureRandom.random_bytes(32) }

  subject(:cipher) { described_class.new(user) }

  describe '#unwrap' do
    let(:encrypted_root) { cipher.wrap(root, 'a secret') }

    it 'returns the root for the secret it was wrapped under' do
      expect(cipher.unwrap(encrypted_root, 'a secret')).to eq(root)
    end

    it 'raises a mismatch error for another secret' do
      expect { cipher.unwrap(encrypted_root, 'another secret') }
        .to raise_error(SiteKeys::RootMismatchError)
    end

    it 'raises an encryption error for a malformed wrap' do
      expect { cipher.unwrap('not json', 'a secret') }
        .to raise_error(Encryption::EncryptionError) do |err|
          expect(err).not_to be_a(SiteKeys::RootMismatchError)
        end
    end

    it 'does not keep the plaintext root in the wrap' do
      expect(encrypted_root).not_to include(Base64.strict_encode64(root))
    end
  end
end
