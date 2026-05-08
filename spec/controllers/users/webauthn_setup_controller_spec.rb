require 'rails_helper'

RSpec.describe Users::WebauthnSetupController do
  include WebAuthnHelper
  include UserAgentHelper
  include AccountCreationThreatMetrixHelper

  def expect_mfa_enrolled(success:, mfa_device_type:)
    expect(@attempts_api_tracker).to receive(:mfa_enrolled).with(
      success: success,
      mfa_device_type: mfa_device_type,
    )
  end

  def expect_user_marked_authenticated
    expect(@analytics).to have_logged_event(
      'User marked authenticated',
      authentication_type: :valid_2fa_confirmation,
    )
  end

  def expect_multi_factor_authentication_setup(attributes)
    attributes = if attributes.instance_of?(Hash)
                   { auto_passkey_prompted: false }.merge(attributes)
    elsif attributes.instance_of?(RSpec::Matchers::BuiltIn::Include)
      include(auto_passkey_prompted: false, **attributes.expecteds.first)
    elsif attributes.instance_of?(RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher)
      hash_including(auto_passkey_prompted: false, **attributes.instance_variable_get(:@expected))
    else
      attributes
    end

    expect(@analytics).to have_logged_event(
      'Multi-Factor Authentication Setup',
      attributes,
    )
  end

  def expect_webauthn_setup_submitted(attributes)
    expect(@analytics).to have_logged_event(
      :webauthn_setup_submitted,
      attributes,
    )
  end

  before do
    stub_analytics
    stub_attempts_tracker
  end

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
      stub_sign_in(user)
    end

    describe '#new' do
      it 'tracks page visit' do
        stub_sign_in

        expect(controller.send(:mobile?)).to be false

        get :new

        expect(@analytics).to have_logged_event(
          'WebAuthn Setup Visited',
          platform_authenticator: false,
          enabled_mfa_methods_count: 0,
          in_account_creation_flow: false,
          auto_passkey_prompted: false,
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
          in_ab_test_bucket: true,
          in_account_creation_flow: true,
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
        expect_mfa_enrolled(success: true, mfa_device_type: 'webauthn')

        patch :confirm, params: params

        expect_user_marked_authenticated
        expect_multi_factor_authentication_setup(
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
        expect_webauthn_setup_submitted(
          platform_authenticator: false,
          in_account_creation_flow: false,
          success: true,
        )
      end

      it 'sends a recovery information changed event' do
        expect(PushNotification::HttpPush).to receive(:deliver)
          .with(PushNotification::RecoveryInformationChangedEvent.new(user: user))

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

        context 'with session value deserialized as a string' do
          before do
            controller.user_session[:webauthn_setup_started_at] =
              2.seconds.ago.to_f.to_s
          end

          it 'calculates duration without error' do
            expect { response }.not_to raise_error

            expect_multi_factor_authentication_setup(
              hash_including(webauthn_setup_duration: a_value_within(0.5).of(2)),
            )
          end
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
          expect_mfa_enrolled(success: true, mfa_device_type: 'webauthn')

          patch :confirm, params: params

          expect_multi_factor_authentication_setup(
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

      context 'auto_trigger for account creation passkey prompt' do
        before do
          controller.user_session[:in_account_creation_flow] = true
        end

        context 'with threatmetrix enabled' do
          let(:tmx_session_id) { '1234' }

          before do
            stub_account_creation_threatmetrix(tmx_session_id: tmx_session_id)
          end

          it 'bootstraps threatmetrix on webauthn setup' do
            expect(controller).to receive(:override_csp_for_threat_metrix)

            get :new, params: { platform: true }

            expect(assigns(:account_creation_threatmetrix)).to eq(
              account_creation_threatmetrix_locals(tmx_session_id: tmx_session_id),
            )
            expect(controller.user_session[:sign_up_threatmetrix_bootstrapped]).to eq(true)
          end

          it 'does not bootstrap threatmetrix twice' do
            controller.user_session[:sign_up_threatmetrix_bootstrapped] = true
            expect(controller).not_to receive(:override_csp_for_threat_metrix)

            get :new, params: { platform: true }

            expect(assigns(:account_creation_threatmetrix)).to eq(
              empty_account_creation_threatmetrix_locals,
            )
          end
        end

        context 'when auto prompt is requested and platform authenticator is used' do
          it 'sets auto_trigger to true' do
            get :new, params: { platform: true, auto_trigger: true }

            expect(assigns(:auto_trigger)).to eq(true)
          end
        end

        context 'when the user was not auto prompted' do
          it 'sets auto_trigger to false' do
            get :new, params: { platform: true }
            expect(assigns(:auto_trigger)).to eq(false)
          end
        end

        context 'when not a platform authenticator' do
          it 'sets auto_trigger to false' do
            get :new, params: { auto_trigger: true }
            expect(assigns(:auto_trigger)).to eq(false)
          end
        end

        context 'when not in account creation flow' do
          before do
            controller.user_session[:in_account_creation_flow] = false
          end

          it 'sets auto_trigger to false' do
            get :new, params: { platform: true, auto_trigger: true }
            expect(assigns(:auto_trigger)).to eq(false)
          end
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

    describe 'auto-passkey-prompt redirect after successful setup' do
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
        allow(IdentityConfig.store).to receive(:domain_name).and_return('localhost:3000')
        request.host = 'localhost:3000'
        controller.user_session[:webauthn_challenge] = webauthn_challenge
        controller.user_session[:in_account_creation_flow] = true
        controller.user_session[:auto_passkey_prompted] = true
      end

      context 'when auto_passkey_prompted is set and no mfa_selections queued' do
        it 'redirects to authentication methods setup after successful platform authenticator setup' do # rubocop:disable Layout/LineLength
          expect_mfa_enrolled(success: true, mfa_device_type: 'webauthn_platform')

          patch :confirm, params: params

          expect(response).to redirect_to(authentication_methods_setup_url)
        end
      end

      context 'when mfa_selections are queued (normal multi-MFA flow takes precedence)' do
        before do
          controller.user_session[:mfa_selections] = ['webauthn_platform', 'voice']
        end

        it 'redirects to the next queued MFA setup instead' do
          expect_mfa_enrolled(success: true, mfa_device_type: 'webauthn_platform')

          patch :confirm, params: params

          expect(response).to redirect_to(phone_setup_url)
        end
      end

      context 'when auto_passkey_prompted is not set' do
        before do
          controller.user_session.delete(:auto_passkey_prompted)
        end

        it 'does not redirect to authentication methods setup' do
          expect_mfa_enrolled(success: true, mfa_device_type: 'webauthn_platform')

          patch :confirm, params: params

          expect(response).not_to redirect_to(authentication_methods_setup_url)
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
          expect_mfa_enrolled(success: true, mfa_device_type: 'webauthn')

          patch :confirm, params: params

          expect_user_marked_authenticated
          expect_multi_factor_authentication_setup(
            enabled_mfa_methods_count: 1,
            in_account_creation_flow: true,
            mfa_method_counts: { webauthn: 1 },
            multi_factor_auth_method: 'webauthn',
            success: true,
            attempts: 1,
            transports: ['usb'],
            transports_mismatch: false,
          )
          expect_webauthn_setup_submitted(
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
          expect_mfa_enrolled(success: true, mfa_device_type: 'webauthn_platform')

          patch :confirm, params: params

          expect_webauthn_setup_submitted(
            platform_authenticator: true,
            in_account_creation_flow: true,
            success: true,
          )
          expect_user_marked_authenticated
          expect(@analytics).to have_logged_event(
            'User Registration: User Fully Registered',
            mfa_method: 'webauthn_platform',
          )
          expect_multi_factor_authentication_setup(
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
          expect_mfa_enrolled(success: false, mfa_device_type: 'webauthn_platform')

          get :new, params: { platform: true, error: 'NotAllowedError' }

          expect_webauthn_setup_submitted(
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
          expect_mfa_enrolled(success: false, mfa_device_type: 'webauthn_platform')

          patch :confirm, params: params

          expect_multi_factor_authentication_setup(
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
        expect_mfa_enrolled(success: true, mfa_device_type: 'webauthn')

        patch :confirm, params: params

        expect_multi_factor_authentication_setup(
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
        expect_webauthn_setup_submitted(
          platform_authenticator: false,
          in_account_creation_flow: true,
          success: true,
        )
      end
    end
  end
end
