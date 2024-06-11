require 'rails_helper'

RSpec.describe Users::WebauthnSetupController, allowed_extra_analytics: [:*] do
  include WebAuthnHelper
  include UserAgentHelper

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

        expect(@analytics).to receive(:track_event).
          with(
            'WebAuthn Setup Visited',
            platform_authenticator: false,
            enabled_mfa_methods_count: 0,
            in_account_creation_flow: false,
          )

        expect(controller.send(:mobile?)).to be false

        get :new
      end

      context 'with a mobile device' do
        it 'sets mobile to true' do
          request.headers['User-Agent'] = mobile_user_agent

          get :new
          expect(controller.send(:mobile?)).to be true
        end
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
          authenticator_data_value: '65',
        }
      end

      before do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        request.host = 'localhost:3000'
        controller.user_session[:webauthn_challenge] = webauthn_challenge
      end

      it 'tracks the submission' do
        Funnel::Registration::AddMfa.call(user.id, 'phone', @analytics)

        patch :confirm, params: params

        expect(@analytics).to have_logged_event(
          'User marked authenticated',
          authentication_type: :valid_2fa_confirmation,
        )
        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication Setup',
          enabled_mfa_methods_count: 3,
          mfa_method_counts: {
            auth_app: 1, phone: 1, webauthn: 1
          },
          multi_factor_auth_method: 'webauthn',
          success: true,
          errors: {},
          in_account_creation_flow: false,
          authenticator_data_flags: {
            up: true,
            uv: false,
            be: false,
            bs: false,
            at: true,
            ed: false,
          },
        )
        expect(@analytics).to have_logged_event(
          :webauthn_setup_submitted,
          platform_authenticator: false,
          success: true,
          errors: nil,
        )
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
      stub_sign_in(user)
      allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
      request.host = 'localhost:3000'
      controller.user_session[:webauthn_challenge] = webauthn_challenge
    end

    describe '#new' do
      context 'with a mobile device' do
        let(:mfa_selections) { ['webauthn'] }

        it 'sets mobile to true' do
          request.headers['User-Agent'] = mobile_user_agent

          get :new
          expect(controller.send(:mobile?)).to be true
        end
      end

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
          expect(controller.send(:mobile?)).to be false
        end
      end

      context 'when the back button is clicked after platform is added' do
        let(:user) { create(:user, :with_webauthn_platform) }
        before do
          controller.user_session[:in_account_creation_flow] = true
        end
        it 'should redirect to authentication methods setup' do
          get :new, params: { platform: true }

          expect(response).to redirect_to(authentication_methods_setup_path)
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

        before do
          controller.user_session[:in_account_creation_flow] = true
        end

        it 'should log expected events' do
          Funnel::Registration::AddMfa.call(user.id, 'phone', @analytics)

          patch :confirm, params: params

          expect(@analytics).to have_logged_event(
            'User marked authenticated',
            authentication_type: :valid_2fa_confirmation,
          )
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            enabled_mfa_methods_count: 1,
            errors: {},
            in_account_creation_flow: true,
            mfa_method_counts: { webauthn: 1 },
            multi_factor_auth_method: 'webauthn',
            success: true,
          )
          expect(@analytics).to have_logged_event(
            :webauthn_setup_submitted,
            errors: nil,
            platform_authenticator: false,
            success: true,
          )
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

        before do
          controller.user_session[:in_account_creation_flow] = true
        end

        it 'should log expected events' do
          patch :confirm, params: params

          expect(@analytics).to have_logged_event(
            :webauthn_setup_submitted,
            errors: nil,
            platform_authenticator: true,
            success: true,
          )
          expect(@analytics).to have_logged_event(
            'User marked authenticated',
            authentication_type: :valid_2fa_confirmation,
          )
          expect(@analytics).to have_logged_event(
            'User Registration: User Fully Registered',
            mfa_method: 'webauthn_platform',
          )
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            enabled_mfa_methods_count: 1,
            errors: {},
            in_account_creation_flow: true,
            mfa_method_counts: { webauthn_platform: 1 },
            multi_factor_auth_method: 'webauthn_platform',
            success: true,
          )
        end

        it 'should log submitted failure' do
          get :new, params: { platform: true, error: 'NotAllowedError' }

          expect(@analytics).to have_logged_event(
            :webauthn_setup_submitted,
            hash_including(
              success: false,
              platform_authenticator: true,
            ),
          )
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
              errors: { name: [I18n.t('errors.webauthn_platform_setup.general_error')] },
              error_details: { name: { attestation_error: true } },
              in_account_creation_flow: false,
              mfa_method_counts: {},
              multi_factor_auth_method: 'webauthn_platform',
              pii_like_keypaths: [[:mfa_method_counts, :phone]],
              success: false,
            },
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
