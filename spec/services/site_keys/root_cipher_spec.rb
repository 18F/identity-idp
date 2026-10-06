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

  describe '#recover' do
    let(:recovery_code) { SiteKeys::RecoveryCode.generate }
    let(:record) do
      build(
        :site_key_root,
        user:,
        encrypted_root_recovery_code: cipher.wrap(
          root, SiteKeys::RecoveryCode.normalize(recovery_code)
        ),
      )
    end

    it 'opens the root with the recovery code' do
      expect(cipher.recover(record, recovery_code.downcase)).to eq(root)
    end

    it 'returns nil for another code' do
      expect(cipher.recover(record, SiteKeys::RecoveryCode.generate)).to be_nil
    end

    it 'returns nil for a malformed code' do
      expect(cipher.recover(record, 'UUUU-UUUU-UUUU-UUUU')).to be_nil
    end
  end
end
