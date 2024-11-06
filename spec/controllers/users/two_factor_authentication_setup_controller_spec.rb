require 'rails_helper'

RSpec.describe Users::TwoFactorAuthenticationSetupController do
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
      )
    end

    it 'initializes presenter with blank ab test bucket value' do
      response

      expect(assigns(:presenter).desktop_ft_ab_test).to be_nil
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

    context 'with user opted in to desktop ft unlock setup ab test' do
      before do
        allow(controller).to receive(:ab_test_bucket).and_return(:desktop_ft_unlock_setup)
      end

      it 'initializes presenter with ab test bucket value' do
        response

        expect(assigns(:presenter).desktop_ft_ab_test).to eq(:desktop_ft_unlock_setup)
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
        errors: {},
      )
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
    end
  end
end
