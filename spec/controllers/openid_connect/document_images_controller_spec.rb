require 'rails_helper'

RSpec.describe OpenidConnect::DocumentImagesController do
  let(:json_response) { JSON.parse(response.body).with_indifferent_access }
  let(:image) { File.read(Rails.root.join('app', 'assets', 'images', 'logo.svg')) }

  describe '#show' do
    subject(:action) do
      request.headers['HTTP_AUTHORIZATION'] = authorization_header
      get :show, params: { image_type: 'front' }
    end

    context 'without an authorization header' do
      let(:authorization_header) { nil }

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

      context 'when the user has a matching escrowed artifact' do
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:written) { EncryptedDocStorage::DocWriter.new.write(image:) }
        let!(:artifact) do
          create(
            :document_artifact,
            profile:,
            image_type: 'front',
            storage_name: written.name,
            encryption_key: written.encryption_key,
          )
        end

        after { File.delete(Rails.root.join('tmp', 'encrypted_doc_storage', written.name)) }

        it 'streams the decrypted image bytes' do
          action

          expect(response).to be_ok
          expect(response.media_type).to eq('image/jpeg')
          expect(response.body).to eq(image)
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
          )
        end

        context 'when the artifact has aged past the retention window' do
          before { artifact.update!(created_at: 91.days.ago) }

          it '404s and audits the denial' do
            stub_analytics

            action

            expect(response).to be_not_found
            expect(@analytics).to have_logged_event(
              :document_image_release,
              hash_including(success: false, denial_reason: :artifact_not_found),
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
      end

      context 'when the document_images scope was not granted' do
        let(:scope) { 'openid profile' }
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        it '403s and audits the denial' do
          stub_analytics

          action

          expect(response).to be_forbidden
          expect(@analytics).to have_logged_event(
            :document_image_release,
            hash_including(success: false, denial_reason: :not_authorized),
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
        end
      end

      context 'when the user has not consented to biometric sharing' do
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        before { identity.update!(biometric_sharing_consent_at: nil) }

        it '403s' do
          action
          expect(response).to be_forbidden
        end
      end

      context 'when there is no artifact for the requested type' do
        let!(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }

        it '404s' do
          action
          expect(response).to be_not_found
        end
      end

      context 'when the underlying object is missing from storage' do
        let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
        let!(:artifact) { create(:document_artifact, profile:, image_type: 'front') }

        it '404s' do
          action
          expect(response).to be_not_found
        end
      end
    end
  end
end
