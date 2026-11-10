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
      let(:access_token) { identity.access_token }
      let(:url) { 'https://idp.example.gov/api/openid_connect/userinfo' }
      let(:bound_thumbprint) { dpop_thumbprint }
      let(:binding) { AccessTokenBinding.new(dpop_jkt: bound_thumbprint) }
      let(:proof) { nil }
      subject(:verifier) do
        AccessTokenVerifier.new(
          http_authorization_header, dpop_proof: proof, http_method: 'GET', http_url: url
        )
      end

      before do
        allow(IdentityConfig.store).to receive(:dpop_required_issuers)
          .and_return([service_provider.issuer])
        allow(AccessTokenBinding).to receive(:load).with(access_token).and_return(binding)
        identity.save!
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii(
          profile_id: 123, pii: {}, expiration: 5,
        )
      end

      context 'presented as a Bearer token' do
        it "is invalid with a 'dpop_bearer_presented' error and an invalid_token challenge" do
          response, result_identity = result

          expect(response.success?).to eq(false)
          expect(result_identity).to be_nil
          expect(response.errors[:dpop_proof]).to eq(['dpop_bearer_presented'])
          expect(verifier.error_message).to eq('dpop_bearer_presented')
          expect(verifier.www_authenticate).to eq('DPoP algs="ES256 RS256", error="invalid_token"')
        end

        it 'does not read the binding record' do
          result
          expect(AccessTokenBinding).not_to have_received(:load)
        end
      end

      context 'presented under the DPoP scheme' do
        let(:http_authorization_header) { "DPoP #{access_token}" }

        context 'when the token has no binding record' do
          let(:binding) { nil }

          it "is invalid with a 'dpop_token_unbound' error and an invalid_token challenge" do
            response, = result

            expect(response.success?).to eq(false)
            expect(response.errors[:dpop_proof]).to eq(['dpop_token_unbound'])
            expect(verifier.www_authenticate).to eq(
              'DPoP algs="ES256 RS256", error="invalid_token"',
            )
          end
        end

        context 'without a proof' do
          it "is invalid with a 'dpop_proof_missing' error and an invalid_dpop_proof challenge" do
            response, = result

            expect(response.success?).to eq(false)
            expect(response.errors[:dpop_proof]).to eq(['dpop_proof_missing'])
            expect(verifier.www_authenticate).to eq(
              'DPoP algs="ES256 RS256", error="invalid_dpop_proof"',
            )
          end
        end

        context 'with a proof' do
          let(:proof_key) { dpop_key }
          let(:proof_url) { url }
          let(:proof) do
            build_dpop_proof(http_url: proof_url, http_method: 'GET', access_token:, key: proof_key)
          end

          context 'from the bound key, for this request' do
            it 'is valid, returns the identity and sets dpop_bound true in the extra attributes' do
              response, result_identity = result

              expect(response.success?).to eq(true)
              expect(result_identity).to eq(identity)
              expect(verifier.www_authenticate).to be_nil
              expect(response.extra[:dpop_bound]).to eq(true)
            end
          end

          context 'signed by another key' do
            let(:proof_key) { OpenSSL::PKey::EC.generate('prime256v1') }

            it "is invalid with a 'dpop_key_mismatch' error in the error details" do
              response, = result

              expect(response.success?).to eq(false)
              expect(response.errors[:dpop_proof]).to eq(['dpop_key_mismatch'])
              expect(response.to_h[:error_details]).to eq(dpop_proof: { dpop_key_mismatch: true })
            end
          end

          context 'for another request' do
            let(:proof_url) { 'https://idp.example.gov/other' }

            it "is invalid with a 'dpop_proof_uri' error" do
              response, = result

              expect(response.success?).to eq(false)
              expect(response.errors[:dpop_proof]).to eq(['dpop_proof_uri'])
            end
          end
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

      it 'is invalid with the malformed_authorization error and no DPoP challenge' do
        response, result_identity = result

        expect(response.success?).to eq(false)
        expect(result_identity).to be_nil
        expect(response.errors[:access_token]).to eq(
          [t('openid_connect.user_info.errors.malformed_authorization')],
        )
        expect(verifier.www_authenticate).to be_nil
      end
    end

    context 'for a client no longer listed for key binding whose token was issued bound' do
      let(:access_token) { identity.access_token }
      let(:url) { 'https://idp.example.gov/api/openid_connect/userinfo' }
      let(:proof) { nil }
      subject(:verifier) do
        AccessTokenVerifier.new(
          http_authorization_header, dpop_proof: proof, http_method: 'GET', http_url: url
        )
      end

      before do
        identity.save!
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_pii(
          profile_id: 123, pii: {}, expiration: 5,
        )
        AccessTokenBinding.store(access_token:, dpop_jkt: dpop_thumbprint, expires_in: 5)
      end

      context 'presented as a Bearer token' do
        it "is invalid with a 'dpop_bearer_presented' error and reports the token as bound" do
          response, result_identity = result

          expect(response.success?).to eq(false)
          expect(result_identity).to be_nil
          expect(response.errors[:dpop_proof]).to eq(['dpop_bearer_presented'])
          expect(response.extra[:dpop_bound]).to eq(true)
          expect(verifier.www_authenticate).to eq('DPoP algs="ES256 RS256", error="invalid_token"')
        end
      end

      context 'presented under the DPoP scheme with a proof from the bound key' do
        let(:http_authorization_header) { "DPoP #{access_token}" }
        let(:proof) { build_dpop_proof(http_url: url, http_method: 'GET', access_token:) }

        it 'is successful' do
          response, result_identity = result

          expect(response.success?).to eq(true)
          expect(result_identity).to eq(identity)
          expect(response.extra[:dpop_bound]).to eq(true)
        end
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
        expect(response.extra[:dpop_bound]).to eq(false)
      end
    end
  end
end
