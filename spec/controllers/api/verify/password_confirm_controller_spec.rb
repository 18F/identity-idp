require 'rails_helper'

describe Api::Verify::PasswordConfirmController do
  include PersonalKeyValidator
  include SamlAuthHelper

  def stub_idv_session
    stub_sign_in(user)
  end

  let(:password) { 'iambatman' }
  let(:user) { create(:user, :signed_up, password: password) }
  let(:applicant) { Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE }

  let(:profile) { subject.idv_session.profile }
  let(:key) { OpenSSL::PKey::RSA.new(Base64.strict_decode64(IdentityConfig.store.idv_private_key)) }
  let(:jwt_metadata) { { vendor_phone_confirmation: true, user_phone_confirmation: true } }
  let(:jwt) { JWT.encode({ pii: applicant, metadata: jwt_metadata }, key, 'RS256', sub: user.uuid) }

  before do
    allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return(['password_confirm'])
  end

  it 'extends behavior of base api class' do
    expect(subject).to be_kind_of Api::Verify::BaseController
  end

  describe '#create' do
    context 'when the user is not signed in and submits the password' do
      it 'does not create a profile or return a key' do
        post :create, params: { password: 'iambatman', user_bundle_token: jwt }
        parsed_body = JSON.parse(response.body, symbolize_names: true)

        expect(response.status).to eq 401
        expect(parsed_body).to eq(errors: { user: 'Unauthorized' })
      end
    end

    context 'when the user is signed in and submits the password' do
      before do
        stub_idv_session
      end

      it 'creates a profile and returns a key and completion url' do
        post :create, params: { password: password, user_bundle_token: jwt }
        parsed_body = JSON.parse(response.body)
        expect(parsed_body).to include(
          'personal_key' => kind_of(String),
          'completion_url' => account_url,
        )
        expect(response.status).to eq 200
      end

      it 'does not create a profile and return a key when it has the wrong password' do
        post :create, params: { password: 'iamnotbatman', user_bundle_token: jwt }
        response_json = JSON.parse(response.body)
        expect(response_json['personal_key']).to be_nil
        expect(response_json['errors']['password']).to eq([I18n.t('idv.errors.incorrect_password')])
        expect(response.status).to eq 400
      end

      context 'with associated sp session' do
        before do
          session[:sp] = { issuer: create(:service_provider).issuer }
        end

        it 'creates a profile and returns completion url' do
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(JSON.parse(response.body)['completion_url']).to eq(sign_up_completed_url)
        end
      end

      context 'with pending profile' do
        let(:jwt_metadata) { { vendor_phone_confirmation: false, user_phone_confirmation: false } }

        it 'creates a profile and returns completion url' do
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(JSON.parse(response.body)['completion_url']).to eq(idv_come_back_later_url)
        end
      end

      context 'with gpo_code returned from form submission and reveal gpo feature enabled' do
        let(:gpo_code) { SecureRandom.hex }

        let(:form) do
          Api::ProfileCreationForm.new(
            password: password,
            jwt: jwt,
            user_session: {},
            service_provider: {},
          )
        end

        before do
          allow(FeatureManagement).to receive(:reveal_gpo_code?).and_return(true)
          allow(subject).to receive(:form).and_return(form)
          allow(form).to receive(:gpo_code).and_return(gpo_code)
        end

        it 'sets code into the session' do
          post :create, params: { password: password, user_bundle_token: jwt }

          expect(session[:last_gpo_confirmation_code]).to eq(gpo_code)
        end
      end
    end

    context 'when the idv api is not enabled' do
      before do
        allow(IdentityConfig.store).to receive(:idv_api_enabled_steps).and_return([])
      end

      it 'responds with not found' do
        post :create, params: { password: password, user_bundle_token: jwt }, as: :json
        expect(response.status).to eq 404
        expect(JSON.parse(response.body)['error']).
          to eq "The page you were looking for doesn't exist"
      end
    end
  end
end
