require 'rails_helper'

RSpec.describe SiteKeys::KeyPair do
  describe '.generate' do
    subject(:key_pair) { described_class.generate }

    it 'has a 32-byte private scalar' do
      expect(key_pair.private_bytes.bytesize).to eq(32)
    end

    it 'is a different key each time' do
      expect(key_pair.private_bytes).not_to eq(described_class.generate.private_bytes)
    end

    it 'has a public JWK with the P-256 public members only' do
      expect(key_pair.public_jwk.keys).to contain_exactly('kty', 'crv', 'x', 'y')
      expect(key_pair.public_jwk).to include('kty' => 'EC', 'crv' => 'P-256')
    end

    it 'has a private JWK that adds the scalar to the public members' do
      expect(key_pair.private_jwk).to include(key_pair.public_jwk)
      expect(Base64.urlsafe_decode64(key_pair.private_jwk.fetch('d'))).to eq(key_pair.private_bytes)
    end

    it 'has a public key without the private scalar' do
      expect(key_pair.public_key.private?).to eq(false)
    end
  end

  describe '.from_private_bytes' do
    let(:generated) { described_class.generate }

    it 'rebuilds the same key pair' do
      rebuilt = described_class.from_private_bytes(generated.private_bytes)

      expect(rebuilt.public_jwk).to eq(generated.public_jwk)
      expect(rebuilt.private_jwk).to eq(generated.private_jwk)
    end

    it 'rebuilds a key that can derive shared secrets' do
      rebuilt = described_class.from_private_bytes(generated.private_bytes)
      peer = OpenSSL::PKey::EC.generate('prime256v1')

      expect(rebuilt.key.derive(peer)).to eq(generated.key.derive(peer))
    end

    it 'rejects bytes of the wrong length' do
      expect { described_class.from_private_bytes(SecureRandom.random_bytes(31)) }
        .to raise_error(ArgumentError)
    end

    it 'rejects nil' do
      expect { described_class.from_private_bytes(nil) }.to raise_error(ArgumentError)
    end

    it 'rejects a zero scalar' do
      expect { described_class.from_private_bytes("\0" * 32) }.to raise_error(ArgumentError)
    end

    it 'rejects a scalar at or above the curve order' do
      expect { described_class.from_private_bytes("\xFF".b * 32) }.to raise_error(ArgumentError)
    end
  end
end
