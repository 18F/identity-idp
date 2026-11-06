require 'rails_helper'

RSpec.describe SiteKeys::Cipher do
  let(:user) { create(:user) }
  let(:private_key) { SecureRandom.random_bytes(32) }

  subject(:cipher) { described_class.new(user) }

  describe '#unwrap' do
    let(:wrap) { cipher.wrap(private_key, 'a secret') }

    it 'returns the key for the secret it was wrapped under' do
      expect(cipher.unwrap(wrap, 'a secret')).to eq(private_key)
    end

    it 'raises a mismatch error for another secret' do
      expect { cipher.unwrap(wrap, 'another secret') }.to raise_error(SiteKeys::MismatchError)
    end

    it 'raises an encryption error for a malformed wrap' do
      expect { cipher.unwrap('not json', 'a secret') }
        .to raise_error(Encryption::EncryptionError) do |err|
          expect(err).not_to be_a(SiteKeys::MismatchError)
        end
    end

    it 'does not keep the plaintext key in the wrap' do
      expect(wrap).not_to include(Base64.strict_encode64(private_key))
    end
  end
end
