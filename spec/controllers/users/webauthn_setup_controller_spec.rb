require 'rails_helper'

RSpec.describe Users::WebauthnSetupController do
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

  context 'when signed in and not account creation' do
    let(:user) { create(:user, :fully_registered, :with_authentication_app) }

    before do
      stub_analytics
      stub_sign_in(user)
    end

    describe '#new' do
      it 'tracks page visit' do
        stub_sign_in
        stub_analytics

        expect(controller.send(:mobile?)).to be false

        get :new

        expect(@analytics).to have_logged_event(
          'WebAuthn Setup Visited',
          platform_authenticator: false,
          enabled_mfa_methods_count: 0,
          in_account_creation_flow: false,
        )
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

    describe '#confirm' do
      subject(:response) { patch :confirm, params: params }

      let(:params) do
        {
          attestation_object: attestation_object,
          client_data_json: setup_client_data_json,
          name: 'mykey',
          transports: 'usb',
          authenticator_data_value: '65',
        }
      end

      let(:threatmetrix_attrs) do
        {
          user_id: user.id,
          request_ip: Faker::Internet.ip_v4_address,
          threatmetrix_session_id: 'test-session',
          email: user.email,
        }
      end

      before do
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        request.host = 'localhost:3000'
        controller.user_session[:webauthn_challenge] = webauthn_challenge
      end

      it 'should flash a success message after successfully creating' do
        response

        expect(flash[:success]).to eq(t('notices.webauthn_configured'))
      end

      it 'redirects to next setup path' do
        expect(response).to redirect_to(account_url)
      end

      it 'tracks the submission' do
        Funnel::Registration::AddMfa.call(user.id, 'phone', @analytics, threatmetrix_attrs)

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
          in_account_creation_flow: false,
          authenticator_data_flags: {
            up: true,
            uv: false,
            be: false,
            bs: false,
            at: true,
            ed: false,
          },
          attempts: 1,
          transports: ['usb'],
          transports_mismatch: false,
        )
        expect(@analytics).to have_logged_event(
          :webauthn_setup_submitted,
          platform_authenticator: false,
          in_account_creation_flow: false,
          success: true,
        )
      end

      it 'creates user event' do
        expect(controller).to receive(:create_user_event).with(:webauthn_key_added)

        response
      end

      context 'with transports mismatch' do
        let(:params) { super().merge(transports: 'internal') }

        it 'handles as successful setup for platform authenticator' do
          expect(controller).to receive(:handle_valid_verification_for_confirmation_context).with(
            auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN_PLATFORM,
          )

          response
        end

        it 'does not flash success message' do
          response

          expect(flash[:success]).to be_nil
        end

        it 'redirects to mismatch confirmation' do
          expect(response).to redirect_to(webauthn_setup_mismatch_url)
        end

        it 'sets session value for mismatched configuration id' do
          response

          expect(controller.user_session[:webauthn_mismatch_id])
            .to eq(user.webauthn_configurations.last.id)
        end
      end

      context 'with platform authenticator set up' do
        let(:params) { super().merge(platform_authenticator: true, transports: 'internal') }

        it 'should flash a success message after successfully creating' do
          response

          expect(flash[:success]).to eq(t('notices.webauthn_platform_configured'))
        end

        it 'creates user event' do
          expect(controller).to receive(:create_user_event).with(:webauthn_platform_added)

          response
        end

        context 'with transports mismatch' do
          let(:params) { super().merge(transports: 'usb') }

          it 'handles as successful setup for cross-platform authenticator' do
            expect(controller).to receive(:handle_valid_verification_for_confirmation_context).with(
              auth_method: TwoFactorAuthenticatable::AuthMethod::WEBAUTHN,
            )

            response
          end

          it 'does not flash success message' do
            response

            expect(flash[:success]).to be_nil
          end

          it 'redirects to mismatch confirmation' do
            expect(response).to redirect_to(webauthn_setup_mismatch_url)
          end

          it 'sets session value for mismatched configuration id' do
            response

            expect(controller.user_session[:webauthn_mismatch_id])
              .to eq(user.webauthn_configurations.last.id)
          end
        end
      end

      context 'with setup from sms recommendation' do
        before do
          controller.user_session[:webauthn_platform_recommended] = :authentication
        end

        it 'logs setup event with session value' do
          patch :confirm, params: params

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            hash_including(webauthn_platform_recommended: :authentication),
          )
        end
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

        let(:threatmetrix_attrs) do
          {
            user_id: user.id,
            request_ip: Faker::Internet.ip_v4_address,
            threatmetrix_session_id: 'test-session',
            email: user.email,
          }
        end

        before do
          controller.user_session[:in_account_creation_flow] = true
        end

        it 'should log expected events' do
          Funnel::Registration::AddMfa.call(user.id, 'phone', @analytics, threatmetrix_attrs)

          patch :confirm, params: params

          expect(@analytics).to have_logged_event(
            'User marked authenticated',
            authentication_type: :valid_2fa_confirmation,
          )
          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            enabled_mfa_methods_count: 1,
            in_account_creation_flow: true,
            mfa_method_counts: { webauthn: 1 },
            multi_factor_auth_method: 'webauthn',
            success: true,
            attempts: 1,
            transports: ['usb'],
            transports_mismatch: false,
          )
          expect(@analytics).to have_logged_event(
            :webauthn_setup_submitted,
            platform_authenticator: false,
            in_account_creation_flow: true,
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
            platform_authenticator: true,
            in_account_creation_flow: true,
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
            in_account_creation_flow: true,
            mfa_method_counts: { webauthn_platform: 1 },
            multi_factor_auth_method: 'webauthn_platform',
            success: true,
            attempts: 1,
            transports: ['internal', 'hybrid'],
            transports_mismatch: false,
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

          patch :confirm, params: params

          expect(@analytics).to have_logged_event(
            'Multi-Factor Authentication Setup',
            enabled_mfa_methods_count: 0,
            error_details: { attestation_object: { invalid: true } },
            in_account_creation_flow: false,
            mfa_method_counts: {},
            multi_factor_auth_method: 'webauthn_platform',
            success: false,
            attempts: 1,
            transports: ['internal', 'hybrid'],
            transports_mismatch: false,
          )
        end
      end
    end

    context 'sign in and confirm' do
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
        controller.user_session[:in_account_creation_flow] = true
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        request.host = 'localhost:3000'
        controller.user_session[:webauthn_challenge] = webauthn_challenge
        controller.user_session[:mfa_attempts] = { auth_method: 'webauthn', attempts: 1 }
      end

      let(:threatmetrix_attrs) do
        {
          user_id: user.id,
          request_ip: Faker::Internet.ip_v4_address,
          threatmetrix_session_id: 'test-session',
          email: user.email,
        }
      end

      it 'tracks the submission' do
        Funnel::Registration::AddMfa.call(user.id, 'phone', @analytics, threatmetrix_attrs)

        patch :confirm, params: params

        expect(@analytics).to have_logged_event(
          'Multi-Factor Authentication Setup',
          enabled_mfa_methods_count: 1,
          mfa_method_counts: {
            webauthn: 1,
          },
          multi_factor_auth_method: 'webauthn',
          success: true,
          in_account_creation_flow: true,
          authenticator_data_flags: {
            up: true,
            uv: false,
            be: false,
            bs: false,
            at: true,
            ed: false,
          },
          attempts: 2,
          transports: ['usb'],
          transports_mismatch: false,
        )
        expect(@analytics).to have_logged_event(
          :webauthn_setup_submitted,
          platform_authenticator: false,
          in_account_creation_flow: true,
          success: true,
        )
      end
    end
  end
end
