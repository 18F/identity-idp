require 'rails_helper'

RSpec.describe Users::WebauthnSetupController do
  include WebAuthnHelper

  describe 'before_actions' do
    it 'includes appropriate before_actions' do
      expect(subject).to have_actions(
        :before,
        :authenticate_user!,
        :confirm_user_authenticated_for_2fa_setup,
        :apply_secure_headers_override,
        :confirm_recently_authenticated_2fa,
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
    let(:user) { create(:user, :fully_registered, :with_authentication_app) }

    before do
      stub_analytics
      stub_sign_in(user)
    end

    describe 'GET new' do
      it 'tracks page visit' do
        stub_sign_in
        stub_analytics
        stub_attempts_tracker

        expect(@analytics).to receive(:track_event).
          with(
            'WebAuthn Setup Visited',
            platform_authenticator: false,
            errors: {},
            enabled_mfa_methods_count: 0,
            in_multi_mfa_selection_flow: false,
            success: true,
          )

        expect(@irs_attempts_api_tracker).not_to receive(:track_event)

        get :new
      end
      context 'when adding webauthn platform to existing user MFA methods' do
        it 'should set need_to_set_up_additional_mfa to false' do
          get :new, params: { platform: true }
          additional_mfa_check = assigns(:need_to_set_up_additional_mfa)
          expect(additional_mfa_check).to be_falsey
        end
      end
    end

    describe 'patch confirm' do
      let(:params) do
        {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
          transports: 'usb',
        }
      end

      before do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        request.host = 'localhost:3000'
        controller.user_session[:webauthn_challenge] = webauthn_challenge
      end

      it 'tracks the submission' do
        Funnel::Registration::AddMfa.call(user.id, 'phone', @analytics)
        result = {
          enabled_mfa_methods_count: 3,
          mfa_method_counts: {
            auth_app: 1, phone: 1, webauthn: 1
          },
          multi_factor_auth_method: 'webauthn',
          success: true,
          errors: {},
          in_multi_mfa_selection_flow: false,
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }
        expect(@analytics).to receive(:track_event).
          with('User marked authenticated', { authentication_type: :valid_2fa_confirmation })
        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication Setup', result)

        expect(@analytics).to receive(:track_event).
          with('Multi-Factor Authentication: Added webauthn', {
            enabled_mfa_methods_count: 3,
            method_name: :webauthn,
            platform_authenticator: false,
          })

        patch :confirm, params: params
      end
    end

    describe 'delete' do
      let(:webauthn_configuration) { create(:webauthn_configuration, user: user) }

      it 'creates a webauthn key removed event' do
        delete :delete, params: { id: webauthn_configuration.id }

        expect(response).to redirect_to(account_two_factor_authentication_path)
        expect(flash.now[:success]).to eq t('notices.webauthn_deleted')
        expect(WebauthnConfiguration.count).to eq(0)
        expect(
          Event.where(
            user_id: controller.current_user.id,
            event_type: :webauthn_key_removed, ip: '0.0.0.0'
          ).count,
        ).to eq 1
      end

      it 'revokes remember device cookies' do
        expect(user.remember_device_revoked_at).to eq nil
        freeze_time do
          delete :delete, params: { id: webauthn_configuration.id }
          expect(user.reload.remember_device_revoked_at).to eq Time.zone.now
        end
      end

      it 'tracks the delete in analytics' do
        result = {
          success: true,
          mfa_method_counts: { auth_app: 1, phone: 1 },
          pii_like_keypaths: [[:mfa_method_counts, :phone]],
        }
        expect(@analytics).to receive(:track_event).with('WebAuthn Deleted', result)

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
    let(:user) { create(:user) }
    let(:params) do
      {
        attestation_object: attestation_object,
        client_data_json: setup_client_data_json,
        name: 'mykey',
        transports: 'usb',
      }
    end

    before do
      stub_analytics
      stub_attempts_tracker
      stub_sign_in(user)
      allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
      request.host = 'localhost:3000'
      controller.user_session[:webauthn_challenge] = webauthn_challenge
    end

    describe 'webauthn platform #new' do
      context 'when in account creation flow and selected multiple mfa' do
        let(:mfa_selections) { ['webauthn_platform', 'voice'] }
        before do
          controller.user_session[:mfa_selections] = mfa_selections
        end

        it 'should set need_to_set_up_additional_mfa to false' do
          get :new, params: { platform: true }
          additional_mfa_check = assigns(:need_to_set_up_additional_mfa)
          expect(additional_mfa_check).to be_falsey
        end
      end

      context 'when in account creation and only have platform as sole MFA method' do
        let(:mfa_selections) { ['webauthn_platform'] }

        before do
          controller.user_session[:mfa_selections] = mfa_selections
        end

        it 'should set need_to_set_up_additional_mfa to true' do
          get :new, params: { platform: true }
          additional_mfa_check = assigns(:need_to_set_up_additional_mfa)
          expect(additional_mfa_check).to be_truthy
        end
      end
    end
    describe 'multiple MFA handling' do
      let(:mfa_selections) { ['webauthn_platform', 'voice'] }

      before do
        controller.user_session[:mfa_selections] = mfa_selections
      end

      context 'with multiple MFA methods chosen on account creation' do
        it 'should direct user to next method confirmation page' do
          patch :confirm, params: params

          expect(response).to redirect_to(phone_setup_url)
        end
      end

      context 'with multiple MFA methods chosen on account creation' do
        let(:params) do
          {
            attestation_object: attestation_object,
            client_data_json: setup_client_data_json,
            name: 'mykey',
            transports: 'usb',
          }
        end
        it 'should log expected events' do
          Funnel::Registration::AddMfa.call(user.id, 'phone', @analytics)
          expect(@analytics).to receive(:track_event).
            with('User marked authenticated', { authentication_type: :valid_2fa_confirmation })
          expect(@analytics).to receive(:track_event).with(
            'Multi-Factor Authentication Setup',
            {
              enabled_mfa_methods_count: 1,
              errors: {},
              in_multi_mfa_selection_flow: true,
              mfa_method_counts: { webauthn: 1 },
              multi_factor_auth_method: 'webauthn',
              pii_like_keypaths: [[:mfa_method_counts, :phone]],
              success: true,
            },
          )

          expect(@analytics).to receive(:track_event).with(
            'Multi-Factor Authentication: Added webauthn',
            {
              enabled_mfa_methods_count: 1,
              method_name: :webauthn,
              platform_authenticator: false,
            },
          )

          expect(@irs_attempts_api_tracker).to receive(:track_event).with(
            :mfa_enroll_webauthn_roaming, success: true
          )

          patch :confirm, params: params
        end
      end

      context 'with a single MFA method chosen on account creation' do
        let(:mfa_selections) { ['webauthn_platform'] }
        it 'should direct user to second mfa suggestion page' do
          patch :confirm, params: params

          expect(response).to redirect_to(auth_method_confirmation_url)
        end
      end

      context 'with only webauthn_platform chosen on account creation' do
        let(:mfa_selections) { ['webauthn_platform'] }
        let(:params) do
          {
            attestation_object: attestation_object,
            client_data_json: setup_client_data_json,
            name: 'mykey',
            transports: 'internal,hybrid',
            platform_authenticator: 'true',
          }
        end
        it 'should log expected events' do
          expect(@analytics).to receive(:track_event).
            with('User marked authenticated', { authentication_type: :valid_2fa_confirmation })
          expect(@analytics).to receive(:track_event).with(
            'User Registration: User Fully Registered',
            { mfa_method: 'webauthn_platform' },
          )

          expect(@analytics).to receive(:track_event).with(
            'Multi-Factor Authentication Setup',
            {
              enabled_mfa_methods_count: 1,
              errors: {},
              in_multi_mfa_selection_flow: true,
              mfa_method_counts: { webauthn_platform: 1 },
              multi_factor_auth_method: 'webauthn_platform',
              pii_like_keypaths: [[:mfa_method_counts, :phone]],
              success: true,
            },
          )

          expect(@analytics).to receive(:track_event).with(
            'Multi-Factor Authentication: Added webauthn',
            {
              enabled_mfa_methods_count: 1,
              method_name: :webauthn,
              platform_authenticator: true,
            },
          )

          expect(@irs_attempts_api_tracker).to receive(:track_event).with(
            :mfa_enroll_webauthn_platform, success: true
          )

          patch :confirm, params: params
        end
      end

      context 'with attestation response error' do
        let(:mfa_selections) { ['webauthn_platform'] }
        let(:params) do
          {
            attestation_object: attestation_object,
            client_data_json: setup_client_data_json,
            name: 'mykey',
            transports: 'internal,hybrid',
            platform_authenticator: 'true',
          }
        end
        it 'should log expected events' do
          allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
          allow(WebAuthn::AttestationStatement).to receive(:from).and_raise(StandardError)

          expect(@analytics).to receive(:track_event).with(
            'Multi-Factor Authentication Setup',
            {
              enabled_mfa_methods_count: 0,
              errors: { name: [I18n.t(
                'errors.webauthn_platform_setup.attestation_error',
                link: MarketingSite.contact_url,
              )] },
              error_details: { name: [I18n.t(
                'errors.webauthn_platform_setup.attestation_error',
                link: MarketingSite.contact_url,
              )] },
              in_multi_mfa_selection_flow: true,
              mfa_method_counts: {},
              multi_factor_auth_method: 'webauthn_platform',
              pii_like_keypaths: [[:mfa_method_counts, :phone]],
              success: false,
            },
          )

          expect(@irs_attempts_api_tracker).to receive(:track_event).with(
            :mfa_enroll_webauthn_platform, success: false
          )

          patch :confirm, params: params
        end
      end
    end

    context 'Multiple MFA options turned off' do
      context 'with a single MFA method chosen' do
        it 'should direct user to second mfa suggestion page' do
          patch :confirm, params: params

          expect(response).to redirect_to(account_url)
        end
      end
    end
  end
end
