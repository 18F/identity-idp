require 'rails_helper'

RSpec.describe OpenidConnect::DocumentImagesController do
  let(:json_response) { JSON.parse(response.body).with_indifferent_access }
  let(:image) { File.read(Rails.root.join('app', 'assets', 'images', 'logo.svg')) }

  describe '#show' do
    subject(:action) do
      request.headers['HTTP_AUTHORIZATION'] = authorization_header
      post :show, params: { image_type: 'front', client_assertion:, client_assertion_type: }
    end

    let(:client_assertion_type) { OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE }
    let(:client_assertion) { JWT.encode(assertion_payload, assertion_key, 'RS256') }
    let(:assertion_key) { OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read) }
    let(:assertion_audience) { api_openid_connect_document_image_url(image_type: 'front') }
    let(:assertion_payload) do
      {
        iss: identity.service_provider,
        sub: identity.service_provider,
        aud: assertion_audience,
        jti: SecureRandom.hex,
        exp: 5.minutes.from_now.to_i,
        iat: Time.zone.now.to_i,
      }
    end

    context 'without an authorization header' do
      let(:authorization_header) { nil }
      let(:client_assertion) { 'unused' }

      it '401s' do
        action
        expect(response).to be_unauthorized
      end
    end

    context 'with a valid bearer token' do
      let(:authorization_header) { "Bearer #{access_token}" }
      let(:access_token) { SecureRandom.hex }
      let(:user) { create(:user) }
      let(:scope) { 'openid document_images' }
      let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_ACR }
      let(:identity) do
        create(
          :service_provider_identity,
          rails_session_id: SecureRandom.hex,
          access_token:,
          scope:,
          acr_values:,
          user:,
          biometric_sharing_consent_at: Time.zone.now,
        )
      end
      let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
      let(:artifact_image_type) { 'front' }
      let(:storage_name) { 'encrypted_images/test-image' }
      let(:encryption_key) { Base64.strict_encode64('x' * 32) }
      let(:doc_reader_response) { image }
      let!(:artifact) do
        create(
          :document_artifact,
          profile:,
          image_type: artifact_image_type,
          storage_name:,
          encryption_key:,
        )
      end

      before do
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
        allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
          .and_return([identity.service_provider])

        allow_any_instance_of(EncryptedDocStorage::DocReader).to receive(:read)
          .with(name: storage_name, encryption_key:).and_return(doc_reader_response)
      end

      context 'when the user has a matching stored artifact' do
        let(:private_key) { OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read) }

        it "returns the image as a JWE encrypted with the SP's public cert" do
          action

          expect(response).to be_ok
          expect(response.media_type).to eq('application/jose')
          header = JSON.parse(Base64.urlsafe_decode64(response.body.split('.').first))
          expect(header).to include(
            'alg' => 'RSA-OAEP', 'enc' => 'A256GCM', 'zip' => 'DEF', 'cty' => 'image/jpeg',
            'kid' => JWT::JWK.new(private_key.public_key).kid
          )
          expect(header).not_to have_key('typ')
          expect(JWE.decrypt(response.body, private_key)).to eq(image)
        end

        it 'cannot be decrypted with another key' do
          other_key = OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read)

          action

          expect { JWE.decrypt(response.body, other_key) }.to raise_error(OpenSSL::PKey::RSAError)
        end

        context 'when the registered key cannot be used for encryption' do
          before do
            allow(OpenidConnect::JweEncryptor).to receive(:encrypt)
              .and_raise(OpenidConnect::JweEncryptor::NoUsableKeyError)
          end

          it 'refuses with server_error and never sends the bytes in the clear' do
            stub_analytics

            action

            expect(response).to have_http_status(:internal_server_error)
            expect(json_response).to eq(
              'error' => 'server_error', 'error_description' => 'encryption_unavailable',
            )
            expect(response.body).not_to include(image)
            expect(@analytics).to have_logged_event(
              :document_image_release,
              success: false,
              image_type: 'front',
              issuer: identity.service_provider,
              error_details: { encryption: { encryption_unavailable: true } },
              profile_id: profile.id,
            )
          end
        end

        it 'forbids caching of the biometric image anywhere downstream' do
          action

          expect(response.headers['Cache-Control']).to eq('no-store')
          expect(response.headers['Pragma']).to eq('no-cache')
          expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
        end

        it 'tracks the image release with an analytic event' do
          stub_analytics

          action

          expect(@analytics).to have_logged_event(
            :document_image_release,
            success: true,
            image_type: 'front',
            issuer: identity.service_provider,
            profile_id: profile.id,
          )
        end

        context 'when the artifact has aged past the retention window' do
          before do
            artifact.update!(
              created_at: (IdentityConfig.store.document_images_ttl_seconds + 60).seconds.ago,
            )
          end

          it '404s and tracks the denial' do
            stub_analytics

            action

            expect(response).to be_not_found
            expect(json_response).to eq(
              'error' => 'image not found',
              'error_description' => 'not_found',
            )
            expect(@analytics).to have_logged_event(
              :document_image_release,
              hash_including(
                success: false,
                error_details: { artifact: { not_found: true } },
              ),
            )
          end
        end

        context 'when the stored key can no longer decrypt the object' do
          let(:doc_reader_response) { nil }

          it '404s instead of raising' do
            action
            expect(response).to be_not_found
          end
        end

        context 'when the stored object has expired out from under the row' do
          let(:doc_reader_response) { nil }

          it '404s and tracks the denial' do
            stub_analytics

            action

            expect(response).to be_not_found
            expect(json_response).to eq(
              'error' => 'image not found',
              'error_description' => 'object_unavailable',
            )
            expect(@analytics).to have_logged_event(
              :document_image_release,
              hash_including(
                success: false,
                error_details: { image: { object_unavailable: true } },
              ),
            )
          end
        end

        context 'when storage is unavailable' do
          before do
            allow_any_instance_of(EncryptedDocStorage::DocReader)
              .to receive(:read).with(name: storage_name, encryption_key:)
              .and_raise(Redis::CannotConnectError)
          end

          it '404s instead of raising' do
            action
            expect(response).to be_not_found
          end
        end
      end

      context 'without a client assertion' do
        let(:client_assertion) { nil }
        let(:client_assertion_type) { nil }

        it '401s with invalid_client and tracks the refusal' do
          stub_analytics

          action

          expect(response).to be_unauthorized
          expect(json_response).to eq(
            'error' => 'invalid_client',
            'error_description' => 'client_assertion_required',
          )
          expect(@analytics).to have_logged_event(
            :document_image_release,
            hash_including(
              success: false,
              error_details: { client_assertion: { client_assertion_required: true } },
            ),
          )
        end
      end

      context 'with a client assertion signed by a key that is not registered' do
        let(:assertion_key) { OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read) }

        it '401s with invalid_signature' do
          action

          expect(response).to be_unauthorized
          expect(json_response['error_description']).to eq(
            'Signature verification failed',
          )
        end
      end

      context 'with a client assertion for another audience' do
        let(:assertion_audience) { api_openid_connect_token_url }
        let(:url) { api_openid_connect_document_image_url(image_type: 'front') }

        it '401s with invalid_aud' do
          action

          expect(response).to be_unauthorized
          expect(json_response['error_description']).to eq(
            t('openid_connect.token.errors.invalid_aud', url:).to_s,
          )
        end
      end

      context 'when the document_images scope was not granted' do
        let(:scope) { 'openid profile' }

        it '403s and tracks the denial' do
          stub_analytics

          action

          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'insufficient_scope',
            'error_description' => 'no_valid_scope',
          )
          expect(@analytics).to have_logged_event(
            :document_image_release,
            hash_including(
              success: false,
              error_details: { scope: { no_valid_scope: true } },
            ),
          )
        end
      end

      context 'when the authorization did not request identity proofing (auth-only ACR)' do
        let(:acr_values) { Saml::Idp::Constants::IAL_AUTH_ONLY_ACR }

        it '403s even though the user has a verified profile and consent' do
          action
          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'insufficient_scope',
            'error_description' => 'no_identity_verification',
          )
        end
      end

      context 'when the authorization requested IALMax' do
        let(:acr_values) { Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF }

        it '403s even though the user has a verified profile and consent' do
          action
          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'insufficient_scope',
            'error_description' => 'no_identity_verification',
          )
        end
      end

      context 'when the SP is not allow-listed for sharing' do
        before do
          allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
            .and_return([])
        end

        it '403s' do
          action
          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'insufficient_scope',
            'error_description' => 'unauthorized_scope',
          )
        end
      end

      context 'when the user has not consented to biometric sharing' do
        before { identity.update!(biometric_sharing_consent_at: nil) }

        it '403s' do
          action
          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'insufficient_scope',
            'error_description' => 'not_consented_to',
          )
        end
      end

      context 'when there is no artifact for the requested type' do
        let(:artifact_image_type) { 'back' }

        it '404s' do
          action
          expect(response).to be_not_found
          expect(json_response).to eq(
            'error' => 'image not found',
            'error_description' => 'not_found',
          )
        end
      end

      context 'when the underlying object is missing from storage' do
        let(:doc_reader_response) { nil }

        it '404s' do
          action
          expect(response).to be_not_found
          expect(json_response).to eq(
            'error' => 'image not found',
            'error_description' => 'object_unavailable',
          )
        end
      end
    end
  end
end
