require 'rails_helper'

RSpec.describe DocumentImagesForm do
  let(:image_type) { 'front' }
  let(:artifact_image_type) { image_type }
  let(:image) { File.read(Rails.root.join('app', 'assets', 'images', 'logo.svg')) }
  let(:user) { create(:user) }
  let(:scope) { 'openid document_images' }
  let(:acr_values) { Saml::Idp::Constants::IAL_VERIFIED_ACR }
  let(:identity) do
    create(
      :service_provider_identity,
      rails_session_id: SecureRandom.hex,
      scope:,
      acr_values:,
      user:,
      biometric_sharing_consent_at: Time.zone.now,
    )
  end
  let(:client_assertion_type) { OpenidConnectTokenForm::CLIENT_ASSERTION_TYPE }
  let(:client_assertion) { JWT.encode(assertion_payload, assertion_key, 'RS256') }
  let(:assertion_key) { OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read) }
  let(:aud) do
    Rails.application.routes.url_helpers.api_openid_connect_document_image_url(image_type:)
  end
  let(:assertion_payload) do
    {
      iss: identity.service_provider,
      sub: identity.service_provider,
      aud:,
      jti: SecureRandom.hex,
      exp: 5.minutes.from_now.to_i,
      iat: Time.zone.now.to_i,
    }
  end
  let(:document_images_params) do
    {
      image_type:,
      client_assertion:,
      client_assertion_type:,
    }
  end
  let(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }
  let(:redis_storage) { EncryptedDocStorage::RedisStorage.new }
  let(:written) { EncryptedDocStorage::DocWriter.new(storage: redis_storage).write(image:) }
  let!(:artifact) do
    create(
      :document_artifact,
      profile:,
      image_type: artifact_image_type,
      storage_name: written.name,
      encryption_key: written.encryption_key,
    )
  end

  subject(:form) { described_class.new(identity:, document_images_params:) }

  before do
    allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
      .and_return([identity.service_provider])
  end

  after { redis_storage.delete_image(name: written.name) }

  let(:response) { form.submit }

  describe '#submit' do
    it 'returns the image and artifact' do
      expect(response).to be_success
      expect(response.extra).to include(
        image:,
        artifact:,
        profile_id: profile.id,
      )
      expect(form.errors).to be_blank
    end

    context 'when no client assertion is included' do
      let(:client_assertion) { nil }
      let(:client_assertion_type) { nil }

      it 'is invalid' do
        expect(response).to_not be_success
        expect(form.errors.details[:code_verifier]).to include(
          error: 'client_assertion_required',
          type: :client_assertion_required,
        )
      end
    end

    context 'when client_assertion key does not match' do
      let(:assertion_key) do
        OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read)
      end

      it 'is invalid' do
        expect(response).to_not be_success
        expect(form.errors[:client_assertion]).to include('Signature verification failed')
      end
    end

    context 'with a client assertion for another audience' do
      let(:aud) do
        Rails.application.routes.url_helpers.api_openid_connect_token_url
      end

      let(:url) do
        Rails.application.routes.url_helpers.api_openid_connect_document_image_url(image_type:)
      end
      it 'is invalid' do
        expect(response).to_not be_success
        expect(form.errors.details[:client_assertion]).to include(
          error: I18n.t('openid_connect.token.errors.invalid_aud', url:),
          type: :invalid_aud,
        )
      end
    end

    context 'when the document_images scope was not granted' do
      let(:scope) { 'openid profile' }

      it 'is invalid' do
        expect(response).to_not be_success
        expect(form.errors.details[:scope]).to include(
          error: 'no_valid_scope',
          type: :no_valid_scope,
        )
      end
    end

    context 'when the authorization did not request identity proofing' do
      let(:acr_values) { Saml::Idp::Constants::IAL_AUTH_ONLY_ACR }

      it 'is invalid' do
        response = form.submit

        expect(response).to_not be_success
        expect(form.errors.details[:acr_values]).to include(
          error: 'no_identity_verification',
          type: :no_identity_verification,
        )
      end
    end

    context 'when the service provider is not allow-listed for sharing' do
      before do
        allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
          .and_return([])
      end

      it 'is invalid' do
        response = form.submit

        expect(response).to_not be_success
        expect(form.errors.details[:scope]).to include(
          error: 'unauthorized_scope',
          type: :unauthorized_scope,
        )
      end
    end

    context 'when the user has not consented to biometric sharing' do
      before { identity.update!(biometric_sharing_consent_at: nil) }

      it 'is invalid' do
        response = form.submit

        expect(response).to_not be_success
        expect(form.errors.details[:scope]).to include(
          error: 'not_consented_to',
          type: :not_consented_to,
        )
      end
    end

    context 'when there is no artifact for the requested type' do
      let(:image_type) { 'back' }
      let(:artifact_image_type) { 'front' }

      it 'is invalid' do
        response = form.submit

        expect(response).to_not be_success
        expect(form.errors.details[:artifact]).to include(error: 'not_found', type: :not_found)
        expect(response.extra).not_to have_key(:artifact)
        expect(response.extra).not_to have_key(:image)
      end
    end

    context 'when the image object is unavailable' do
      before { redis_storage.delete_image(name: written.name) }

      it 'is invalid' do
        response = form.submit

        expect(response).to_not be_success
        expect(form.errors.details[:image]).to include(
          error: 'object_unavailable',
          type: :object_unavailable,
        )
        expect(response.extra).not_to have_key(:artifact)
        expect(response.extra).not_to have_key(:image)
      end
    end
  end

  describe '#error_response' do
    subject(:error_response) do
      form.valid?
      form.error_response
    end

    context 'with no errors' do
      it { expect(error_response).to be_nil }
    end

    context 'when no client assertion is included' do
      let(:client_assertion) { nil }
      let(:client_assertion_type) { nil }

      it 'returns an invalid client response' do
        expect(error_response).to have_attributes(
          status: :unauthorized,
          error: 'invalid_client',
          error_description: 'Code verifier client_assertion_required',
        )
      end
    end

    context 'when client_assertion key does not match' do
      let(:assertion_key) do
        OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read)
      end

      it 'returns an invalid client response' do
        expect(error_response).to have_attributes(
          status: :unauthorized,
          error: 'invalid_client',
          error_description: 'Client assertion Signature verification failed',
        )
      end
    end

    context 'with a client assertion for another audience' do
      let(:aud) do
        Rails.application.routes.url_helpers.api_openid_connect_token_url
      end

      let(:url) do
        Rails.application.routes.url_helpers.api_openid_connect_document_image_url(image_type:)
      end

      it 'returns an invalid client response' do
        expect(error_response).to have_attributes(
          status: :unauthorized,
          error: 'invalid_client',
          error_description: "Client assertion #{I18n.t(
            'openid_connect.token.errors.invalid_aud',
            url:,
          )}",
        )
      end
    end

    context 'when the document_images scope was not granted' do
      let(:scope) { 'openid profile' }

      it 'returns a forbidden response' do
        expect(error_response).to have_attributes(
          status: :forbidden,
          error: 'document_images sharing is not authorized',
          error_description: 'Scope no_valid_scope',
        )
      end
    end

    context 'when the authorization did not request identity proofing' do
      let(:acr_values) { Saml::Idp::Constants::IAL_AUTH_ONLY_ACR }

      it 'returns a forbidden response' do
        expect(error_response).to have_attributes(
          status: :forbidden,
          error: 'document_images sharing is not authorized',
          error_description: 'Acr values no_identity_verification',
        )
      end
    end

    context 'when the service provider is not allow-listed for sharing' do
      before do
        allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
          .and_return([])
      end

      it 'returns a forbidden response' do
        expect(error_response).to have_attributes(
          status: :forbidden,
          error: 'document_images sharing is not authorized',
          error_description: 'Scope unauthorized_scope',
        )
      end
    end

    context 'when the user has not consented to biometric sharing' do
      before { identity.update!(biometric_sharing_consent_at: nil) }

      it 'returns a forbidden response' do
        expect(error_response).to have_attributes(
          status: :forbidden,
          error: 'document_images sharing is not authorized',
          error_description: 'Scope not_consented_to',
        )
      end
    end

    context 'when there is no artifact for the requested type' do
      let(:image_type) { 'back' }
      let(:artifact_image_type) { 'front' }

      it 'returns a not found response' do
        expect(error_response).to have_attributes(
          status: :not_found,
          error: 'images not found',
          error_description: 'Artifact not_found',
        )
      end
    end

    context 'when the image object is unavailable' do
      before { redis_storage.delete_image(name: written.name) }

      it 'returns a not found response' do
        expect(error_response).to have_attributes(
          status: :not_found,
          error: 'images not found',
          error_description: 'Image object_unavailable',
        )
      end
    end
  end
end
