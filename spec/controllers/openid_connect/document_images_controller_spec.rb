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

      before do
        OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
        allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(true)
        allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
          .and_return([identity.service_provider])
      end

      context 'when the user has a matching stored artifact' do
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let(:redis_storage) { EncryptedDocStorage::RedisStorage.new }
        let!(:written) { EncryptedDocStorage::DocWriter.new(storage: redis_storage).write(image:) }
        let!(:artifact) do
          create(
            :document_artifact,
            profile:,
            image_type: 'front',
            storage_name: written.name,
            encryption_key: written.encryption_key,
          )
        end

        after { redis_storage.delete_image(name: written.name) }

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
              error_details: { encryption: ['encryption_unavailable'] },
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

        it 'writes an audit event recording the release' do
          stub_analytics

          action

          expect(@analytics).to have_logged_event(
            :document_image_release,
            success: true,
            image_type: 'front',
            issuer: identity.service_provider,
            profile_id: profile.id,
            encrypted: true,
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
              'error' => 'images not found',
              'error_description' => 'Artifact not_found',
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
          before do
            allow_any_instance_of(EncryptedDocStorage::DocReader)
              .to receive(:read).and_return(nil)
          end

          it '404s instead of raising' do
            action
            expect(response).to be_not_found
          end
        end

        context 'when the Redis object has expired out from under the row' do
          before { redis_storage.delete_image(name: written.name) }

          it '404s and tracks the denial' do
            stub_analytics

            action

            expect(response).to be_not_found
            expect(json_response).to eq(
              'error' => 'images not found',
              'error_description' => 'Image object_unavailable',
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

        context 'when Redis is unavailable' do
          before do
            allow_any_instance_of(EncryptedDocStorage::RedisStorage)
              .to receive(:read_image).and_raise(Redis::CannotConnectError)
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
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }

        it '401s with invalid_client and tracks the refusal' do
          stub_analytics

          action

          expect(response).to be_unauthorized
          expect(json_response).to eq(
            'error' => 'invalid_client',
            'error_description' => 'Code verifier client_assertion_required',
          )
          expect(@analytics).to have_logged_event(
            :document_image_release,
            hash_including(
              success: false,
              error_details: { code_verifier: { client_assertion_required: true } },
            ),
          )
        end
      end

      context 'with a client assertion signed by a key that is not registered' do
        let(:assertion_key) { OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read) }
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        it '401s with invalid_signature' do
          action

          expect(response).to be_unauthorized
          expect(json_response['error_description']).to eq(
            'Client assertion Signature verification failed',
          )
        end
      end

      context 'with a client assertion for another audience' do
        let(:assertion_audience) { api_openid_connect_token_url }
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        it '401s with invalid_aud' do
          action

          expect(response).to be_unauthorized
          expect(json_response['error_description']).to eq(
            "Client assertion #{t(
              'openid_connect.token.errors.invalid_aud',
              url: api_openid_connect_document_image_url(image_type: 'front'),
)}",
          )
        end
      end

      context 'when the document_images scope was not granted' do
        let(:scope) { 'openid profile' }
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        it '403s and tracks the denial' do
          stub_analytics

          action

          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'document_images sharing is not authorized',
            'error_description' => 'Scope no_valid_scope',
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
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        it '403s even though the user has a verified profile and consent' do
          action
          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'document_images sharing is not authorized',
            'error_description' => 'Acr values no_identity_verification',
          )
        end
      end

      context 'when the authorization requested IALMax' do
        let(:acr_values) { Saml::Idp::Constants::IALMAX_AUTHN_CONTEXT_CLASSREF }
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        it '403s even though the user has a verified profile and consent' do
          action
          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'document_images sharing is not authorized',
            'error_description' => 'Acr values no_identity_verification',
          )
        end
      end

      context 'when the SP is not allow-listed for sharing' do
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        before do
          allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
            .and_return([])
        end

        it '403s' do
          action
          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'document_images sharing is not authorized',
            'error_description' => 'Scope unauthorized_scope',
          )
        end
      end

      context 'when the user has not consented to biometric sharing' do
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        before { identity.update!(biometric_sharing_consent_at: nil) }

        it '403s' do
          action
          expect(response).to be_forbidden
          expect(json_response).to eq(
            'error' => 'document_images sharing is not authorized',
            'error_description' => 'Scope not_consented_to',
          )
        end
      end

      context 'when there is no artifact for the requested type' do
        let!(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }

        it '404s' do
          action
          expect(response).to be_not_found
          expect(json_response).to eq(
            'error' => 'images not found',
            'error_description' => 'Artifact not_found',
          )
        end
      end

      context 'when the underlying object is missing from storage' do
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        it '404s' do
          action
          expect(response).to be_not_found
          expect(json_response).to eq(
            'error' => 'images not found',
            'error_description' => 'Image object_unavailable',
          )
        end
      end
    end
  end
end
