require 'rails_helper'

RSpec.describe SiteKeys::Sealer do
  let(:issuer) { 'urn:gov:gsa:openidconnect:test' }
  let(:recipient) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:key) { SecureRandom.random_bytes(32) }

  subject(:sealer) { described_class.new(issuer:, recipient:) }

  describe '#seal' do
    it 'is readable by the holder of the recipient key' do
      sealed = sealer.seal(key:)

      expect(open_sealed_site_key(sealed, recipient:, issuer:)).to eq(
        'k' => Base64.urlsafe_encode64(key, padding: false),
      )
    end

    it 'is bound to the issuer' do
      sealed = sealer.seal(key:)

      expect { open_sealed_site_key(sealed, recipient:, issuer: 'urn:other') }
        .to raise_error(OpenSSL::Cipher::CipherError)
    end

    it 'includes email addresses when given' do
      sealed = sealer.seal(key:, email: 'a@example.com', emails: ['a@example.com', 'b@example.com'])

      expect(open_sealed_site_key(sealed, recipient:, issuer:)).to include(
        'email' => 'a@example.com',
        'emails' => ['a@example.com', 'b@example.com'],
      )
    end

    it 'includes only the email addresses given' do
      sealed = sealer.seal(key:, email: 'a@example.com')

      opened = open_sealed_site_key(sealed, recipient:, issuer:)

      expect(opened.keys).to contain_exactly('k', 'email')
    end

    it 'produces a versioned payload with a 12-byte IV and a 16-byte tag' do
      payload = JSON.parse(Base64.urlsafe_decode64(sealer.seal(key:)))
      plaintext_bytes = { k: Base64.urlsafe_encode64(key, padding: false) }.to_json.bytesize

      expect(payload.keys).to contain_exactly('v', 'epk', 'iv', 'ct')
      expect(payload['v']).to eq(described_class::VERSION)
      expect(Base64.urlsafe_decode64(payload['iv']).bytesize).to eq(12)
      expect(Base64.urlsafe_decode64(payload['ct']).bytesize).to eq(plaintext_bytes + 16)
    end

    it 'rejects a key of the wrong size' do
      expect { sealer.seal(key: 'short') }.to raise_error(SiteKeys::SealError)
    end

    context 'with a recipient on another curve' do
      let(:recipient) { OpenSSL::PKey::EC.generate('secp384r1') }

      it 'raises a seal error' do
        expect { sealer.seal(key:) }.to raise_error(SiteKeys::SealError)
      end
    end

    it 'uses a fresh ephemeral key each time' do
      first = JSON.parse(Base64.urlsafe_decode64(sealer.seal(key:)))
      second = JSON.parse(Base64.urlsafe_decode64(sealer.seal(key:)))

      expect(first['epk']).not_to eq(second['epk'])
    end
  end
end
