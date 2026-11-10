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

    context 'with no expiration claim' do
      before { jwt_payload.delete(:exp) }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: t('openid_connect.token.errors.missing_exp'),
          type: :missing_exp,
        )
      end
    end

    context 'with an expiration further from the issued at claim than the maximum lifetime' do
      before { jwt_payload[:exp] = 1.hour.from_now.to_i }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: t(
            'openid_connect.token.errors.invalid_exp',
            seconds: IdentityConfig.store.client_assertion_max_lifetime_seconds,
          ),
          type: :invalid_exp,
        )
      end
    end

    context 'with no issued at claim and an expiration beyond the maximum lifetime from now' do
      before do
        jwt_payload.delete(:iat)
        jwt_payload[:exp] = 1.hour.from_now.to_i
      end

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(type: :invalid_exp)
      end
    end

    context 'with an expiration exactly at the maximum lifetime' do
      before do
        jwt_payload[:exp] = jwt_payload[:iat] +
                            IdentityConfig.store.client_assertion_max_lifetime_seconds
      end

      it 'is valid' do
        expect(validator.valid?).to eq(true)
      end
    end

    context 'with no jti claim' do
      before { jwt_payload.delete(:jti) }

      it 'is invalid' do
        expect(validator.valid?).to eq(false)
        expect(validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: t('openid_connect.token.errors.missing_jti'),
          type: :missing_jti,
        )
      end
    end

    context 'when the same assertion is presented a second time' do
      let(:second_validator) do
        described_class.new(client_assertion:, client_id:, service_provider:, audience_url:)
      end

      it 'accepts the first presentation and refuses the replay' do
        expect(validator.valid?).to eq(true)
        expect(second_validator.valid?).to eq(false)
        expect(second_validator.errors.first).to have_attributes(
          attribute: :client_assertion,
          message: t('openid_connect.token.errors.replayed_jti'),
          type: :replayed_jti,
        )
      end

      it 'answers the same for the same instance asked twice' do
        expect(validator.valid?).to eq(true)
        expect(validator.valid?).to eq(true)
        expect(validator.errors).to be_blank
      end
    end

    context 'when a second assertion from the same client carries a different jti' do
      let(:second_assertion) do
        JWT.encode(jwt_payload.merge(jti: SecureRandom.hex), client_private_key, 'RS256')
      end
      let(:second_validator) do
        described_class.new(
          client_assertion: second_assertion, client_id:, service_provider:, audience_url:,
        )
      end

      it 'accepts both' do
        expect(validator.valid?).to eq(true)
        expect(second_validator.valid?).to eq(true)
      end
    end

    context 'when the same jti is presented by a different client' do
      let(:other_client_id) { 'other-client-issuer' }
      let(:other_service_provider) do
        create(:service_provider, certs: ['saml_test_sp'], issuer: other_client_id)
      end
      let(:other_assertion) do
        JWT.encode(
          jwt_payload.merge(iss: other_client_id, sub: other_client_id),
          client_private_key,
          'RS256',
        )
      end
      let(:other_validator) do
        described_class.new(
          client_assertion: other_assertion,
          client_id: other_client_id,
          service_provider: other_service_provider,
          audience_url:,
        )
      end

      it 'does not treat it as a replay' do
        expect(validator.valid?).to eq(true)
        expect(other_validator.valid?).to eq(true)
      end
    end

    context 'when an assertion refused for another reason is corrected and presented again' do
      let(:refused_validator) do
        described_class.new(
          client_assertion: JWT.encode(
            jwt_payload.merge(aud: 'https://example.com/invalid'), client_private_key, 'RS256'
          ),
          client_id:,
          service_provider:,
          audience_url:,
        )
      end

      it 'did not consume the jti' do
        expect(refused_validator.valid?).to eq(false)
        expect(validator.valid?).to eq(true)
      end
    end
  end
end
