require 'rails_helper'

RSpec.describe Users::TwoFactorAuthenticationSetupController do
  include AccountCreationThreatMetrixHelper

  describe 'GET index' do
    let(:user) { create(:user) }

    subject(:response) { get :index }

    before do
      stub_sign_in_before_2fa(user) if user
      stub_analytics
    end

    it 'tracks the visit in analytics' do
      get :index

      expect(@analytics).to have_logged_event(
        'User Registration: 2FA Setup visited',
        enabled_mfa_methods_count: 0,
        gov_or_mil_email: false,
        in_account_creation_flow: false,
        auto_passkey_prompted: false,
      )
    end

    context 'with threatmetrix disabled' do
      before do
        allow(FeatureManagement).to receive(:proofing_device_profiling_collecting_enabled?)
          .and_return(false)
      end

      it 'does not override CSPs for ThreatMetrix' do
        expect(controller).not_to receive(:override_csp_for_threat_metrix)

        response
      end
    end

    context 'with threatmetrix enabled' do
      let(:tmx_session_id) { '1234' }

      before do
        stub_account_creation_threatmetrix(tmx_session_id: tmx_session_id)
      end

      it 'renders new valid request' do
        expect(controller).to receive(:render).with(
          :index,
          locals: account_creation_threatmetrix_locals(tmx_session_id: tmx_session_id),
        ).and_call_original

        expect(response).to render_template(:index)
      end

      it 'overrides CSPs for ThreatMetrix' do
        expect(controller).to receive(:override_csp_for_threat_metrix)

        response
      end

      context 'when threatmetrix is already bootstrapped' do
        before do
          controller.user_session[:sign_up_threatmetrix_bootstrapped] = true
        end

        it 'does not override CSPs for ThreatMetrix again' do
          expect(controller).not_to receive(:override_csp_for_threat_metrix)

          response
        end
      end
    end

    context 'with user having gov or mil email' do
      let!(:federal_domain) { create(:federal_email_domain, name: 'gsa.gov') }
      let(:user) do
        create(
          :user,
          email: 'example@gsa.gov',
          piv_cac_recommended_dismissed_at: interstitial_dismissed_at,
        )
      end

      context 'having already visited the PIV interstitial page' do
        let(:interstitial_dismissed_at) { Time.zone.now }

        it 'tracks the visit in analytics' do
          get :index

          expect(@analytics).to have_logged_event(
            'User Registration: 2FA Setup visited',
            enabled_mfa_methods_count: 0,
            gov_or_mil_email: true,
            in_account_creation_flow: false,
            auto_passkey_prompted: false,
          )
        end
      end

      context 'directed to page without having visited PIV interstitial page' do
        let(:interstitial_dismissed_at) { nil }

        it 'redirects user to piv_recommended_path' do
          get :index

          expect(response).to redirect_to(login_piv_cac_recommended_url)
        end
      end
    end

    context 'when signed out' do
      let(:user) { nil }

      it 'redirects to sign in page' do
        get :index

        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'when fully authenticated and MFA enabled' do
      let(:user) { build(:user, :with_phone) }

      before do
        stub_sign_in(user)
      end

      it 'logs the visit event with mfa method count' do
        get :index

        expect(@analytics).to have_logged_event(
          'User Registration: 2FA Setup visited',
          enabled_mfa_methods_count: 1,
          gov_or_mil_email: false,
          in_account_creation_flow: false,
          auto_passkey_prompted: false,
        )
      end
    end

    context 'when fully authenticated but not MFA enabled' do
      it 'allows access' do
        stub_sign_in

        get :index

        expect(response).to render_template(:index)
      end
    end

    context 'already two factor enabled but not fully authenticated' do
      let(:user) { build(:user, :fully_registered) }

      it 'prompts for 2FA' do
        get :index

        expect(response).to redirect_to(user_two_factor_authentication_url)
      end
    end

    context 'when account creation passkey prompt is enabled' do
      before do
        allow(FeatureManagement).to receive(:account_creation_passkey_auto_prompt_enabled?)
          .and_return(true)
        controller.user_session[:in_account_creation_flow] = true
      end

      context 'when platform authenticator is available' do
        before do
          controller.user_session[:platform_authenticator_available] = true
        end

        context 'when user is in the auto prompt bucket' do
          before do
            allow(controller).to receive(:ab_test_bucket)
              .with(:PASSKEY_UPSELL)
              .and_return(:auto_passkey_prompt)
          end

          it 'redirects to platform webauthn setup' do
            expect { response }
              .to change { controller.user_session[:auto_passkey_prompted] }
              .from(nil)
              .to(true)

            expect(response).to redirect_to(webauthn_setup_url(platform: true, auto_trigger: true))
          end

          it 'does not auto prompt after it has already been triggered once' do
            controller.user_session[:auto_passkey_prompted] = true

            get :index

            expect(response).to render_template(:index)
            expect(controller.user_session[:auto_passkey_prompted]).to eq(true)
          end
        end

        context 'when user is in the control bucket' do
          before do
            allow(controller).to receive(:ab_test_bucket)
              .with(:PASSKEY_UPSELL)
              .and_return(:mfa_selection)
          end

          it 'renders the mfa selection page' do
            get :index

            expect(response).to render_template(:index)
          end
        end
      end

      context 'when platform authenticator is not available' do
        before do
          controller.user_session[:platform_authenticator_available] = false
        end

        it 'does not redirect to platform webauthn setup' do
          get :index

          expect(response).to render_template(:index)
        end
      end
    end
  end

  describe '#create' do
    let(:params) { { two_factor_options_form: { selection: ['voice'] } } }

    subject(:response) { patch :create, params: params }

    before do
      stub_sign_in_before_2fa
    end

    it 'tracks analytics event' do
      stub_analytics

      response

      expect(@analytics).to have_logged_event(
        'User Registration: 2FA Setup',
        enabled_mfa_methods_count: 0,
        selection: ['voice'],
        success: true,
        selected_mfa_count: 1,
      )
    end

    it 'assigns platform_authenticator_available session value' do
      expect { response }.to change { controller.user_session[:platform_authenticator_available] }
        .from(nil)
        .to(false)
    end

    context 'when multi selection with phone first' do
      let(:params) { { two_factor_options_form: { selection: ['phone', 'auth_app'] } } }

      it { is_expected.to redirect_to phone_setup_url }
    end

    context 'when multi selection with auth app first' do
      let(:params) { { two_factor_options_form: { selection: ['auth_app', 'phone', 'webauthn'] } } }

      it { is_expected.to redirect_to authenticator_setup_url }
    end

    context 'when the selection is auth_app' do
      let(:params) { { two_factor_options_form: { selection: ['auth_app'] } } }

      it { is_expected.to redirect_to authenticator_setup_url }
    end

    context 'when the selection is webauthn' do
      let(:params) { { two_factor_options_form: { selection: ['webauthn'] } } }

      it { is_expected.to redirect_to webauthn_setup_url }
    end

    context 'when the selection is webauthn platform authenticator' do
      let(:params) { { two_factor_options_form: { selection: ['webauthn_platform'] } } }

      it { is_expected.to redirect_to webauthn_setup_url(platform: true) }
    end

    context 'when the selection is piv_cac' do
      let(:params) { { two_factor_options_form: { selection: ['piv_cac'] } } }

      it { is_expected.to redirect_to setup_piv_cac_url }
    end

    context 'when the selection is not valid' do
      let(:params) { { two_factor_options_form: { selection: ['foo'] } } }

      it 'renders setup page with error message' do
        expect(response).to render_template(:index)
        expect(flash[:error]).to eq(t('errors.messages.inclusion'))
      end

      context 'with threatmetrix enabled' do
        let(:tmx_session_id) { '1234' }

        before do
          stub_account_creation_threatmetrix(tmx_session_id: tmx_session_id)
        end

        it 'renders new with invalid request' do
          expect(controller).to receive(:render).with(
            :index,
            locals: account_creation_threatmetrix_locals(tmx_session_id: tmx_session_id),
          ).and_call_original

          expect(response).to render_template(:index)
        end
      end
    end

    context 'with form value indicating platform authenticator support' do
      let(:params) { super().merge(platform_authenticator_available: 'true') }

      it 'assigns platform_authenticator_available session value' do
        expect do
          response
        end.to change { controller.user_session[:platform_authenticator_available] }
          .from(nil)
          .to(true)
      end
    end
  end
end
