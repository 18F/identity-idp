require 'rails_helper'

RSpec.describe 'OpenID Connect userinfo encrypted responses' do
  let(:access_token) { SecureRandom.hex }
  let(:certs) { ['saml_test_sp'] }
  let(:service_provider) { create(:service_provider, ial: 2, certs:) }
  let(:allowed_issuers) { [service_provider.issuer] }
  let(:user) { create(:user) }
  let(:identity) do
    create(
      :service_provider_identity,
      rails_session_id: SecureRandom.hex,
      access_token:,
      user:,
      service_provider_record: service_provider,
      scope: 'openid email',
      acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
      last_authenticated_at: Time.zone.now,
    )
  end
  let(:private_key) { OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp.key').read) }
  let(:other_private_key) do
    OpenSSL::PKey::RSA.new(Rails.root.join('keys', 'saml_test_sp2.key').read)
  end

  before do
    allow(IdentityConfig.store).to receive(:userinfo_encryption_allowed_issuers)
      .and_return(allowed_issuers)
    OutOfBandSessionAccessor.new(identity.rails_session_id).put_empty_user_session(50)
  end

  def userinfo(authorization: "Bearer #{access_token}")
    get api_openid_connect_userinfo_path, headers: { 'HTTP_AUTHORIZATION' => authorization }
  end

  # The claims exactly as the plain response carries them for this identity, read with the
  # service provider taken off the list for one request.
  def plain_claims
    allow(IdentityConfig.store).to receive(:userinfo_encryption_allowed_issuers).and_return([])
    userinfo
    expect(response.media_type).to eq('application/json')
    claims = JSON.parse(response.body)
    allow(IdentityConfig.store).to receive(:userinfo_encryption_allowed_issuers)
      .and_return(allowed_issuers)
    claims
  end

  def jwe_header(compact_jwe)
    JSON.parse(Base64.urlsafe_decode64(compact_jwe.split('.').first))
  end

  # In a request spec there is no controller instance until the request has run, so the
  # controller-spec `stub_analytics` has nothing to stub; stub every controller instead.
  def stub_request_analytics
    @analytics = FakeAnalytics.new
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(@analytics)
  end

  describe 'a service provider on the list' do
    it 'answers with one compact JWE under application/jwt and nothing in the clear' do
      userinfo

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/jwt')
      expect(response.body.split('.').length).to eq(5)
      expect(response.body).not_to include(user.email_addresses.first.email)
      expect(response.body).not_to include(identity.uuid)
    end

    it 'encrypts with the shared parameters, naming the registered key in the header' do
      userinfo

      expect(jwe_header(response.body)).to eq(
        'alg' => 'RSA-OAEP',
        'enc' => 'A256GCM',
        'zip' => 'DEF',
        'typ' => 'JWT',
        'kid' => JWT::JWK.new(private_key.public_key).kid,
      )
    end

    it 'decrypts with the key of the registered certificate to exactly the plain claims' do
      freeze_time do
        expected = plain_claims
        userinfo

        decrypted = JSON.parse(JWE.decrypt(response.body, private_key))
        expect(decrypted).to eq(expected)
        expect(decrypted).to include('sub' => identity.uuid, 'email_verified' => true)
        expect(decrypted['email']).to eq(user.email_addresses.first.email)
      end
    end

    it 'cannot be decrypted with another key' do
      userinfo

      expect { JWE.decrypt(response.body, other_private_key) }
        .to raise_error(OpenSSL::PKey::RSAError)
    end

    it 'logs the authentication with the encrypted flag' do
      stub_request_analytics
      userinfo

      expect(@analytics).to have_logged_event(
        'OpenID Connect: bearer token authentication',
        success: true, ial: identity.ial, client_id: service_provider.issuer, encrypted: true,
      )
    end
  end

  describe 'document images for a listed service provider' do
    let(:identity) do
      create(
        :service_provider_identity,
        rails_session_id: SecureRandom.hex,
        access_token:,
        user:,
        service_provider_record: service_provider,
        scope: 'openid email document_images',
        acr_values: Saml::Idp::Constants::IAL_VERIFIED_ACR,
        last_authenticated_at: Time.zone.now,
        biometric_sharing_consent_at: Time.zone.now,
      )
    end
    let!(:profile) { create(:profile, :active, user:, verified_at: 1.hour.ago) }

    before do
      allow(IdentityConfig.store).to receive(:document_images_sharing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:document_images_sharing_service_providers)
        .and_return([service_provider.issuer])
    end

    def decrypted_claims
      JSON.parse(JWE.decrypt(response.body, private_key))
    end

    context 'with a stored image' do
      let(:redis_storage) { EncryptedDocStorage::RedisStorage.new }
      let(:image) { File.read(Rails.root.join('app', 'assets', 'images', 'logo.svg')) }
      let!(:written) { EncryptedDocStorage::DocWriter.new(storage: redis_storage).write(image:) }

      before do
        create(
          :document_artifact,
          profile:,
          image_type: 'selfie',
          storage_name: written.name,
          encryption_key: written.encryption_key,
          document_capture_session: create(:document_capture_session, user:),
        )
      end

      after { redis_storage.delete_image(name: written.name) }

      it 'carries the image bytes inside the encrypted claims and nowhere else' do
        userinfo

        expect(response.media_type).to eq('application/jwt')
        expect(response.body).not_to include(Base64.urlsafe_encode64(image, padding: false))
        expect(decrypted_claims['document_images']).to eq(
          'selfie' => {
            'content_type' => 'image/jpeg',
            'data' => Base64.urlsafe_encode64(image, padding: false),
          },
        )
        expect(decrypted_claims).to have_key('document_metadata')
      end

      it 'records the release with the image types and never the image' do
        stub_request_analytics
        userinfo

        expect(@analytics).to have_logged_event(
          :document_image_release,
          success: true,
          image_types: ['selfie'],
          issuer: service_provider.issuer,
          profile_id: profile.id,
        )
      end
    end

    context 'when sharing is authorized but no image has been retrieved yet' do
      it 'carries an empty document_images object inside the encrypted claims' do
        userinfo

        expect(decrypted_claims['document_images']).to eq({})
        expect(decrypted_claims['document_metadata']).to eq({})
      end
    end

    context 'when the service provider is not listed for encrypted responses' do
      let(:allowed_issuers) { [] }

      it 'answers in the clear with neither document claim' do
        stub_request_analytics
        userinfo

        expect(response.media_type).to eq('application/json')
        body = JSON.parse(response.body)
        expect(body).not_to have_key('document_images')
        expect(body).not_to have_key('document_metadata')
        expect(@analytics).not_to have_logged_event(:document_image_release)
      end
    end
  end

  describe 'a service provider not on the list' do
    let(:allowed_issuers) { ['some-other-issuer'] }

    it 'receives the plain JSON response exactly as before' do
      stub_request_analytics
      userinfo

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      body = JSON.parse(response.body)
      expect(body).to include('sub' => identity.uuid, 'email_verified' => true)
      expect(body['email']).to eq(user.email_addresses.first.email)
      expect(@analytics).to have_logged_event(
        'OpenID Connect: bearer token authentication',
        success: true, ial: identity.ial, client_id: service_provider.issuer, encrypted: false,
      )
    end
  end

  describe 'a listed service provider without a usable key' do
    shared_examples 'a refused request that releases nothing' do
      it 'answers 500 server_error with no claim in the body and logs the failure' do
        stub_request_analytics
        userinfo

        expect(response).to have_http_status(:internal_server_error)
        expect(response.media_type).to eq('application/json')
        expect(JSON.parse(response.body)).to eq(
          'error' => 'server_error',
          'error_description' => t('openid_connect.user_info.errors.encryption_unavailable'),
        )
        expect(response.body).not_to include(user.email_addresses.first.email)
        expect(response.body).not_to include(identity.uuid)
        expect(response.body).not_to include('"sub"')
        expect(@analytics).to have_logged_event(
          :openid_connect_userinfo_encryption_failed,
          client_id: service_provider.issuer,
          error: 'OpenidConnect::JweEncryptor::NoUsableKeyError',
        )
      end
    end

    context 'with no registered certificate' do
      let(:certs) { [] }

      include_examples 'a refused request that releases nothing'
    end

    context 'with a certificate name that does not exist' do
      let(:certs) { ['i_do_not_exist'] }

      include_examples 'a refused request that releases nothing'
    end
  end

  describe 'an invalid token' do
    it 'is refused before any response is built, with no encrypted flag' do
      stub_request_analytics
      userinfo(authorization: 'Bearer not-a-known-token')

      expect(response).to have_http_status(:unauthorized)
      expect(response.media_type).to eq('application/json')
      expect(@analytics).to have_logged_event(
        'OpenID Connect: bearer token authentication',
        success: false, error_details: { access_token: { not_found: true } },
      )
    end
  end
end
