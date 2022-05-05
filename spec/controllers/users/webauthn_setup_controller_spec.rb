require 'rails_helper'

describe Users::WebauthnSetupController do
  include WebAuthnHelper

  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :confirm_user_authenticated_for_2fa_setup,
      )
    end
  end

  describe 'when not signed in' do
    describe 'GET new' do
      it 'redirects to root url' do
        get :new

        expect(response).to redirect_to(root_url)
      end
    end

    describe 'patch confirm' do
      it 'redirects to root url' do
        patch :confirm

        expect(response).to redirect_to(root_url)
      end
    end
  end

  describe 'when signed in and not account creation' do
    let(:user) { create(:user, :signed_up, :with_authentication_app) }

    before do
      stub_analytics
      stub_sign_in(user)
    end

    describe 'GET new' do
      it 'tracks page visit' do
        stub_sign_in
        stub_analytics

        expect(@analytics).to receive(:track_event).
          with(Analytics::WEBAUTHN_SETUP_VISIT, platform_authenticator: false,
                                                errors: {}, success: true)

        get :new
      end
    end

    describe 'patch confirm' do
      let(:params) do
        {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
        }
      end

      before do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        controller.user_session[:webauthn_challenge] = webauthn_challenge
      end

      it 'tracks the submission' do
        result = {
          success: true,
          errors: {},
          mfa_method_counts: {
            auth_app: 1, phone: 1, webauthn: 1
          },
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
          multi_factor_auth_method: 'webauthn',
        }
        expect(@analytics).to receive(:track_event).
          with(Analytics::MULTI_FACTOR_AUTH_SETUP, result)

        patch :confirm, params: params
      end
    end

    describe 'delete' do
      let(:webauthn_configuration) { create(:webauthn_configuration, user: user) }

      it 'creates a webauthn key removed event' do
        expect(Event).to receive(:create).
          with(hash_including(
            user_id: controller.current_user.id,
            event_type: :webauthn_key_removed, ip: '0.0.0.0'
          ))

        delete :delete, params: { id: webauthn_configuration.id }

        expect(response).to redirect_to(account_two_factor_authentication_path)
        expect(flash.now[:success]).to eq t('notices.webauthn_deleted')
        expect(WebauthnConfiguration.count).to eq(0)
      end

      it 'tracks the delete in analytics' do
        result = {
          success: true,
          mfa_method_counts: { auth_app: 1, phone: 1 },
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }
        expect(@analytics).to receive(:track_event).with(Analytics::WEBAUTHN_DELETED, result)

        delete :delete, params: { id: webauthn_configuration.id }
      end

      it 'sends a recovery information changed event' do
        expect(PushNotification::HttpPush).to receive(:deliver).
          with(PushNotification::RecoveryInformationChangedEvent.new(user: user))

        delete :delete, params: { id: webauthn_configuration.id }
      end
    end

    describe 'show_delete' do
      let(:webauthn_configuration) { create(:webauthn_configuration, user: user) }

      it 'renders page when configuration exists' do
        get :show_delete, params: { id: webauthn_configuration.id }
        expect(response).to render_template :delete
      end

      it 'redirects when the configuration does not exist' do
        get :show_delete, params: { id: '_' }
        expect(response).to redirect_to(new_user_session_url)
        expect(flash[:error]).to eq t('errors.general')
      end
    end
  end

  describe 'when signed in and account creation' do
    let(:user) { create(:user, :signed_up) }
    let(:params) do
      {
        attestation_object: attestation_object,
        client_data_json: setup_client_data_json,
        name: 'mykey',
      }
    end

    before do
      stub_analytics
      stub_sign_in(user)
      allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
      controller.user_session[:webauthn_challenge] = webauthn_challenge
    end

    context 'with multiple MFA methods chosen on account creation' do
      before do
        controller.user_session[:selected_mfa_options] = ['webauthn_platform', 'voice']
        allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return true
      end

      it 'should direct user to phone page' do
        patch :confirm, params: params

        expect(response).to redirect_to(auth_method_confirmation_url(next_setup_choice: 'voice'))
      end
    end

    context 'with a single MFA method chosen on account creation' do
      it 'should direct user to account page' do
        patch :confirm, params: params

        expect(response).to redirect_to(account_url)
      end
    end
  end
end
