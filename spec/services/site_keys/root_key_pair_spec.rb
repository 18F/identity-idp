require 'rails_helper'

RSpec.describe SiteKeys::RootKeyPair do
  describe '.generate' do
    subject(:key_pair) { described_class.generate }

    it 'has a 32-byte private scalar' do
      expect(key_pair.private_bytes.bytesize).to eq(32)
    end

    it 'is a different key each time' do
      expect(key_pair.private_bytes).not_to eq(described_class.generate.private_bytes)
    end

    it 'has a public JWK that RecipientJwk accepts' do
      parsed = SiteKeys::RecipientJwk.parse(key_pair.public_jwk)

      expect(parsed.public_to_der).to eq(key_pair.public_key.public_to_der)
    end

    it 'has a public key without the private scalar' do
      expect(key_pair.public_key.private?).to eq(false)
    end

    it 'can open data sealed to its public key' do
      issuer = 'urn:gov:gsa:openidconnect:test'
      key = SecureRandom.random_bytes(32)
      sealed = SiteKeys::Sealer.new(issuer:, recipient: key_pair.public_key).seal(key:)

      expect(open_sealed_site_key(sealed, recipient: key_pair.key, issuer:)).to eq(
        'k' => Base64.urlsafe_encode64(key, padding: false),
      )
    end
  end

  describe '.from_private_bytes' do
    let(:generated) { described_class.generate }

    it 'rebuilds the same key pair' do
      rebuilt = described_class.from_private_bytes(generated.private_bytes)

      expect(rebuilt.public_jwk).to eq(generated.public_jwk)
    end

    it 'rebuilds a key that can derive shared secrets' do
      rebuilt = described_class.from_private_bytes(generated.private_bytes)
      peer = OpenSSL::PKey::EC.generate('prime256v1')

      expect(rebuilt.key.derive(peer)).to eq(generated.key.derive(peer))
    end

    it 'rejects bytes of the wrong length' do
      expect { described_class.from_private_bytes(SecureRandom.random_bytes(31)) }
        .to raise_error(SiteKeys::SealError)
    end

    it 'rejects nil' do
      expect { described_class.from_private_bytes(nil) }.to raise_error(SiteKeys::SealError)
    end

    it 'rejects a zero scalar' do
      expect { described_class.from_private_bytes("\0" * 32) }.to raise_error(SiteKeys::SealError)
    end

    it 'rejects a scalar at or above the curve order' do
      expect { described_class.from_private_bytes("\xFF".b * 32) }
        .to raise_error(SiteKeys::SealError)
    end
  end
end
