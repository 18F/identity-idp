require 'rails_helper'

RSpec.describe AccessTokenVerifier do
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  subject(:verifier) { AccessTokenVerifier.new(http_authorization_header) }
  let(:http_authorization_header) { "Bearer #{access_token}" }

  let(:identity) do
    build(
      :service_provider_identity,
      rails_session_id: '123',
      access_token: SecureRandom.urlsafe_base64,
    )
  end

  describe '#submit' do
    let(:result) { verifier.submit }

    context 'without an authorization header' do
      let(:http_authorization_header) { nil }

      it 'is not successful' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(response.errors[:access_token])
          .to include(t('openid_connect.user_info.errors.no_authorization'))
        expect(result_identity).to be_nil
      end
    end

    context 'with a malformed authorization header' do
      let(:http_authorization_header) { 'BOOOO ABCDEF' }

      it 'is not successful' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(response.errors[:access_token])
          .to include(t('openid_connect.user_info.errors.malformed_authorization'))
        expect(result_identity).to be_nil
      end
    end

    context 'with an invalid bearer token' do
      let(:access_token) { 'ABDEF' }

      it 'is not successful' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(response.errors[:access_token]).to be_present
        expect(result_identity).to be_nil
      end
    end

    context 'with a bearer token for an expired session' do
      before { OutOfBandSessionAccessor.new(identity.rails_session_id).destroy }

      let(:access_token) { identity.access_token }

      it 'is not successful' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(response.errors[:access_token]).to be_present
        expect(result_identity).to be_nil
      end
    end

    context 'for a client Login.gov lists for key binding' do
      let(:service_provider) do
        create(:service_provider, :active, issuer: 'bound-client', pkce: true)
      end
      let(:identity) do
        build(
          :service_provider_identity,
          service_provider: service_provider.issuer,
          rails_session_id: '123',
          access_token: SecureRandom.urlsafe_base64,
        )
      end
      let(:bound_thumbprint) { dpop_thumbprint }
      let(:access_token) { identity.access_token }
      let(:url) { 'https://idp.example.gov/api/openid_connect/userinfo' }
      let(:proof) { build_dpop_proof(http_url: url, http_method: 'GET', access_token:) }
      subject(:verifier) do
        AccessTokenVerifier.new(
          http_authorization_header, dpop_proof: proof, http_method: 'GET', http_url: url
        )
      end

      before do
        allow(IdentityConfig.store).to receive(:dpop_required_issuers)
          .and_return([service_provider.issuer])
        identity.save!
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii(
          profile_id: 123, pii: {}, expiration: 5,
        )
        # What the token endpoint wrote when it issued the access token to a bound client.
        if bound_thumbprint
          AccessTokenBinding.store(
            access_token:, dpop_jkt: bound_thumbprint, expires_in: 60,
          )
        end
      end

      context 'with the DPoP scheme and a proof from the bound key' do
        let(:http_authorization_header) { "DPoP #{access_token}" }

        it 'is successful and reports the binding for analytics' do
          response, result_identity = result

          expect(response.success?).to eq(true)
          expect(result_identity).to eq(identity)
          expect(verifier.www_authenticate).to be_nil
          expect(response.extra[:dpop_bound]).to eq(true)
          expect(response.extra[:dpop_error_type]).to be_nil
        end
      end

      context 'presented as a Bearer token' do
        it 'is refused with a DPoP challenge' do
          response, result_identity = result

          expect(response.success?).to eq(false)
          expect(result_identity).to be_nil
          expect(response.errors[:dpop_proof]).to eq(
            [t('openid_connect.user_info.errors.dpop_bearer_presented')],
          )
          expect(verifier.www_authenticate).to eq('DPoP algs="ES256 RS256", error="invalid_token"')
          expect(verifier.error_message).to eq(
            t('openid_connect.user_info.errors.dpop_bearer_presented'),
          )
        end
      end

      context 'with the DPoP scheme and no proof' do
        let(:http_authorization_header) { "DPoP #{access_token}" }
        let(:proof) { nil }

        it 'is refused as a missing proof' do
          response, = result

          expect(response.success?).to eq(false)
          expect(response.errors[:dpop_proof]).to eq(
            [t('openid_connect.token.errors.dpop_proof_required')],
          )
          expect(verifier.www_authenticate).to eq(
            'DPoP algs="ES256 RS256", error="invalid_dpop_proof"',
          )
        end
      end

      context 'with a proof signed by another key' do
        let(:http_authorization_header) { "DPoP #{access_token}" }
        let(:proof) do
          build_dpop_proof(
            http_url: url, http_method: 'GET', access_token:, key: OpenSSL::PKey::EC.generate('prime256v1'),
          )
        end

        it 'is refused as a key mismatch, named for analytics' do
          response, = result

          expect(response.success?).to eq(false)
          expect(response.errors[:dpop_proof]).to eq(
            [t('openid_connect.token.errors.dpop_key_mismatch')],
          )
          expect(response.extra[:dpop_error_type]).to eq(:dpop_key_mismatch)
        end
      end

      context 'with a proof for another request' do
        let(:http_authorization_header) { "DPoP #{access_token}" }
        let(:proof) do
          build_dpop_proof(
            http_url: 'https://idp.example.gov/other', http_method: 'GET', access_token:,
          )
        end

        it 'is refused' do
          response, = result

          expect(response.success?).to eq(false)
          expect(response.errors[:dpop_proof]).to eq(
            [t('openid_connect.token.errors.dpop_proof_invalid')],
          )
        end
      end

      context 'when the token has no binding record, because none was written or it expired' do
        let(:http_authorization_header) { "DPoP #{access_token}" }
        let(:bound_thumbprint) { nil }

        it 'is refused until the person signs in again with a key' do
          response, = result

          expect(response.success?).to eq(false)
          expect(response.errors[:dpop_proof]).to eq(
            [t('openid_connect.user_info.errors.dpop_token_unbound')],
          )
          expect(verifier.www_authenticate).to eq('DPoP algs="ES256 RS256", error="invalid_token"')
        end
      end
    end

    context 'for a client not listed for key binding, presenting the DPoP scheme' do
      let(:access_token) { identity.access_token }
      let(:http_authorization_header) { "DPoP #{access_token}" }
      let(:url) { 'https://idp.example.gov/api/openid_connect/userinfo' }
      subject(:verifier) do
        AccessTokenVerifier.new(
          http_authorization_header,
          dpop_proof: build_dpop_proof(http_url: url, http_method: 'GET', access_token:),
          http_method: 'GET',
          http_url: url,
        )
      end
      before do
        identity.save!
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii(
          profile_id: 123, pii: {}, expiration: 5,
        )
      end

      it 'is malformed, as it always was, and carries no challenge' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(result_identity).to be_nil
        expect(response.errors[:access_token]).to eq(
          [t('openid_connect.user_info.errors.malformed_authorization')],
        )
        expect(verifier.www_authenticate).to be_nil
      end
    end

    context 'with a valid bearer token' do
      let(:access_token) { identity.access_token }
      before do
        identity.save!
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii(
          profile_id: 123,
          pii: {},
          expiration: 5,
        )
      end

      it 'is successful' do
        response, result_identity = result

        expect(response.success?).to eq(true)
        expect(response.errors).to be_blank
        expect(result_identity).to eq(identity)
      end
    end
  end
end
