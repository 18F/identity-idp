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

      it 'carries no challenge and reads nothing but the header' do
        verifier = AccessTokenVerifier.new(
          http_authorization_header,
          dpop_proof: 'ignored-for-a-bearer-token', http_method: 'GET', http_url: 'https://x/y',
        )
        response, result_identity = verifier.submit

        expect(response.success?).to eq(true)
        expect(result_identity).to eq(identity)
        expect(verifier.www_authenticate).to be_nil
      end

      context 'presented under the DPoP scheme' do
        let(:http_authorization_header) { "DPoP #{access_token}" }

        it 'is refused as not bound, with a DPoP challenge' do
          response, result_identity = result

          expect(response.success?).to eq(false)
          expect(response.errors[:access_token])
            .to eq([t('openid_connect.user_info.errors.token_not_bound')])
          expect(response.to_h[:error_details]).to eq(access_token: { token_not_bound: true })
          expect(result_identity).to be_nil
          expect(verifier.www_authenticate)
            .to eq('DPoP algs="ES256 RS256", error="invalid_token"')
        end
      end
    end

    context 'with a token bound to a key' do
      let(:url) { 'https://idp.example.gov/api/openid_connect/userinfo' }
      let(:identity) do
        build(
          :service_provider_identity,
          rails_session_id: '123',
          access_token: SecureRandom.urlsafe_base64,
          dpop_jkt: dpop_thumbprint,
        )
      end
      let(:access_token) { identity.access_token }
      let(:http_authorization_header) { "DPoP #{access_token}" }
      let(:dpop_proof) { build_dpop_proof(url:, method: 'GET', access_token:) }

      subject(:verifier) do
        AccessTokenVerifier.new(
          http_authorization_header, dpop_proof:, http_method: 'GET', http_url: url
        )
      end

      before do
        identity.save!
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
      end

      it 'is successful with a proof from the bound key for this request' do
        response, result_identity = result

        expect(response.success?).to eq(true)
        expect(result_identity).to eq(identity)
        expect(verifier.www_authenticate).to be_nil
      end

      context 'presented as a bearer token' do
        let(:http_authorization_header) { "Bearer #{access_token}" }

        it 'is refused with an invalid_token DPoP challenge' do
          response, result_identity = result

          expect(response.success?).to eq(false)
          expect(response.errors[:access_token])
            .to eq([t('openid_connect.user_info.errors.bound_token_requires_dpop')])
          expect(response.to_h[:error_details])
            .to eq(access_token: { bound_token_requires_dpop: true })
          expect(result_identity).to be_nil
          expect(response.to_h[:client_id]).to eq(identity.service_provider)
          expect(verifier.www_authenticate)
            .to eq('DPoP algs="ES256 RS256", error="invalid_token"')
        end
      end

      context 'without a proof' do
        let(:dpop_proof) { nil }

        it 'is refused with an invalid_dpop_proof challenge' do
          response, result_identity = result

          expect(response.success?).to eq(false)
          expect(response.errors[:access_token])
            .to eq([t('openid_connect.token.errors.dpop_proof_required')])
          expect(result_identity).to be_nil
          expect(verifier.www_authenticate)
            .to eq('DPoP algs="ES256 RS256", error="invalid_dpop_proof"')
        end
      end

      context 'with a proof from a different key' do
        let(:dpop_proof) do
          build_dpop_proof(
            url:, method: 'GET', access_token:, key: OpenSSL::PKey::EC.generate('prime256v1'),
          )
        end

        it 'is refused' do
          response, = result
          expect(response.success?).to eq(false)
          expect(response.to_h[:error_details]).to eq(access_token: { dpop_key_mismatch: true })
          expect(verifier.www_authenticate)
            .to eq('DPoP algs="ES256 RS256", error="invalid_dpop_proof"')
        end
      end

      context 'with a proof for another method or URL, or without ath' do
        it 'is refused' do
          [
            build_dpop_proof(url:, method: 'POST', access_token:),
            build_dpop_proof(
              url: 'https://idp.example.gov/api/openid_connect/token',
              method: 'GET', access_token:
            ),
            build_dpop_proof(url:, method: 'GET'),
          ].each do |proof|
            verifier = AccessTokenVerifier.new(
              http_authorization_header, dpop_proof: proof, http_method: 'GET', http_url: url
            )
            response, result_identity = verifier.submit
            expect(response.success?).to eq(false)
            expect(result_identity).to be_nil
            expect(verifier.www_authenticate).to include('error="invalid_dpop_proof"')
          end
        end
      end

      context 'with a replayed proof' do
        it 'accepts the first use and refuses the second' do
          expect(result.first.success?).to eq(true)

          again = AccessTokenVerifier.new(
            http_authorization_header, dpop_proof:, http_method: 'GET', http_url: url
          )
          response, = again.submit
          expect(response.success?).to eq(false)
          expect(response.to_h[:error_details]).to eq(access_token: { dpop_proof_replayed: true })
        end
      end
    end
  end
end
