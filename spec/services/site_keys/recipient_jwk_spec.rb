require 'rails_helper'

RSpec.describe SiteKeys::RecipientJwk do
  let(:key) { OpenSSL::PKey::EC.generate('prime256v1') }
  let(:jwk) { JWT::JWK.new(key).export.slice(:kty, :crv, :x, :y).stringify_keys }

  describe '.parse' do
    subject(:parse) { described_class.parse(encoded) }

    let(:encoded) { Base64.urlsafe_encode64(jwk.to_json, padding: false) }

    it 'returns the public key' do
      expect(parse.public_key.to_bn).to eq(key.public_key.to_bn)
    end

    context 'with WebCrypto exportKey metadata' do
      let(:encoded) do
        Base64.urlsafe_encode64(
          jwk.merge('ext' => true, 'key_ops' => [], 'alg' => 'ECDH-ES').to_json,
          padding: false,
        )
      end

      it 'returns the public key' do
        expect(parse.public_key.to_bn).to eq(key.public_key.to_bn)
      end
    end

    context 'with a private key' do
      let(:encoded) do
        Base64.urlsafe_encode64(JWT::JWK.new(key).export(include_private: true).to_json)
      end

      it 'raises a seal error' do
        expect { parse }.to raise_error(SiteKeys::SealError)
      end
    end

    context 'with an unknown member' do
      let(:encoded) { Base64.urlsafe_encode64(jwk.merge('x5c' => []).to_json) }

      it 'raises a seal error' do
        expect { parse }.to raise_error(SiteKeys::SealError)
      end
    end

    context 'with another curve' do
      let(:encoded) { Base64.urlsafe_encode64(jwk.merge('crv' => 'P-384').to_json) }

      it 'raises a seal error' do
        expect { parse }.to raise_error(SiteKeys::SealError)
      end
    end

    context 'with a coordinate that is not a 32-byte base64url string' do
      let(:encoded) { Base64.urlsafe_encode64(jwk.merge('x' => 1).to_json) }

      it 'raises a seal error' do
        expect { parse }.to raise_error(SiteKeys::SealError)
      end
    end

    context 'with a point that is not on the curve' do
      let(:encoded) do
        off_curve_y = Base64.urlsafe_encode64("\x01" * 32, padding: false)
        Base64.urlsafe_encode64(jwk.merge('y' => off_curve_y).to_json)
      end

      it 'raises a seal error' do
        expect { parse }.to raise_error(SiteKeys::SealError)
      end
    end

    context 'with a coordinate of the wrong length' do
      let(:encoded) do
        short_x = Base64.urlsafe_encode64("\x01" * 31, padding: false)
        Base64.urlsafe_encode64(jwk.merge('x' => short_x).to_json)
      end

      it 'raises a seal error' do
        expect { parse }.to raise_error(SiteKeys::SealError)
      end
    end

    context 'with JSON that is not an object' do
      let(:encoded) { Base64.urlsafe_encode64('[]') }

      it 'raises a seal error' do
        expect { parse }.to raise_error(SiteKeys::SealError)
      end
    end

    context 'with no value' do
      let(:encoded) { nil }

      it 'raises a seal error' do
        expect { parse }.to raise_error(SiteKeys::SealError)
      end
    end

    context 'with a value that is not base64 JSON' do
      let(:encoded) { 'not-base64!!' }

      it 'raises a seal error' do
        expect { parse }.to raise_error(SiteKeys::SealError)
      end
    end
  end
end
