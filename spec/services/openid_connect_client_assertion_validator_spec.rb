require 'rails_helper'

RSpec.describe OpenidConnectClientAssertionValidator do
  include Rails.application.routes.url_helpers

  subject(:validator) do
    described_class.new(
      client_assertion:,
      client_id:,
      service_provider:,
      audience_url:,
    )
  end

  let(:service_provider) do
    create(
      :service_provider,
      certs: ['saml_test_sp2', 'saml_test_sp'],
      issuer: client_id,
    )
  end
  let(:client_id) { 'client-issuer' }
  let(:audience_url) { api_openid_connect_token_url }
  let(:client_assertion) { JWT.encode(jwt_payload, client_private_key, 'RS256') }
  let(:jwt_payload) do
    {
      iss: client_id,
      sub: client_id,
      aud: audience_url,
      jti: SecureRandom.hex,
      exp: 5.minutes.from_now.to_i,
      iat: Time.zone.now.to_i,
    }
  end
  let(:client_private_key) do
    OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read)
  end

  describe '#valid?' do
    it 'is valid for a matching private key JWT client assertion' do
      expect(validator.valid?).to eq(true)
      expect(validator.errors).to be_blank
    end

    context 'with a trailing slash in the audience claim' do
      before { jwt_payload[:aud] = "#{audience_url}/" }

      it 'is valid' do
        expect(validator.valid?).to eq(true)
      end
    end

    context 'with a list of audiences including the expected audience' do
      before { jwt_payload[:aud] = ['another-audience', audience_url] }

      it 'is valid' do
        expect(validator.valid?).to eq(true)
      end
    end

    context 'with no issued at claim' do
      before { jwt_payload.delete(:iat) }

      it 'is valid' do
        expect(validator.valid?).to eq(true)
      end
    end

    context 'with an invalid audience' do
      before { jwt_payload[:aud] = 'https://example.com/invalid' }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: t('openid_connect.token.errors.invalid_aud', url: audience_url),
          type: :invalid_aud,
        )
      end
    end

    context 'with an invalid issuer' do
      before { jwt_payload[:iss] = 'wrong-issuer' }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: "Invalid issuer. Expected [\"#{client_id}\"], received wrong-issuer",
          type: :invalid_signature,
        )
      end
    end

    context 'with an invalid subject' do
      before { jwt_payload[:sub] = 'wrong-subject' }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: "Invalid subject. Expected #{client_id}, received wrong-subject",
          type: :invalid_signature,
        )
      end
    end

    context 'with an expired assertion' do
      before { jwt_payload[:exp] = 5.minutes.ago.to_i }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: 'Signature has expired',
          type: :invalid_signature,
        )
      end
    end

    context 'with an issued at claim in the future' do
      before { jwt_payload[:iat] = Time.zone.now.to_i + 1.minute.to_i }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: t('openid_connect.token.errors.invalid_iat'),
          type: :invalid_iat,
        )
      end
    end

    context 'with no registered certificates' do
      before { service_provider.update!(certs: []) }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: t('openid_connect.token.errors.invalid_signature'),
          type: :invalid_signature,
        )
      end
    end

    context 'when signed by an unknown key' do
      let(:client_private_key) { OpenSSL::PKey::RSA.new(2048) }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: 'Signature verification failed',
          type: :invalid_signature,
        )
      end
    end
  end
end
