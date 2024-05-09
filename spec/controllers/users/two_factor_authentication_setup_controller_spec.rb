require 'rails_helper'

RSpec.describe Users::TwoFactorAuthenticationSetupController, allowed_extra_analytics: [:*] do
  describe 'GET index' do
    let(:user) { create(:user) }

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

    context 'with user having gov or mil email' do
      let(:user) do
        create(:user, email: 'example@example.gov', piv_cac_recommended_dismissed_at: Time.zone.now)
      end
      context 'having already visited the PIV interstitial page' do
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
        let(:user) do
          create(:user, email: 'example@example.gov')
        end

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
  end

  describe 'PATCH create' do
    it 'submits the TwoFactorOptionsForm' do
      user = build(:user)
      stub_sign_in_before_2fa(user)
      stub_analytics

      voice_params = {
        two_factor_options_form: {
          selection: ['voice'],
        },
      }

      expect(controller.two_factor_options_form).to receive(:submit).
        with(hash_including(voice_params[:two_factor_options_form])).and_call_original

      patch :create, params: voice_params

      expect(@analytics).to have_logged_event(
        'User Registration: 2FA Setup',
        success: true,
        errors: {},
        enabled_mfa_methods_count: 0,
        selected_mfa_count: 1,
        selection: ['voice'],
      )
    end

    it 'tracks analytics event' do
      stub_sign_in_before_2fa
      stub_analytics

      result = {
        enabled_mfa_methods_count: 0,
        selection: ['voice', 'auth_app'],
        success: true,
        selected_mfa_count: 2,
        errors: {},
      }

      expect(@analytics).to receive(:track_event).
        with('User Registration: 2FA Setup', result)

      patch :create, params: {
        two_factor_options_form: {
          selection: ['voice', 'auth_app'],
        },
      }
    end

    it 'tracks IRS attempts event' do
      stub_sign_in_before_2fa
      stub_attempts_tracker

      expect(@irs_attempts_api_tracker).to receive(:track_event).
        with(:mfa_enroll_options_selected, success: true,
                                           mfa_device_types: ['voice', 'auth_app'])

      patch :create, params: {
        two_factor_options_form: {
          selection: ['voice', 'auth_app'],
        },
      }
    end

    context 'when multi selection with phone first' do
      it 'redirects properly' do
        stub_sign_in_before_2fa
        patch :create, params: {
          two_factor_options_form: {
            selection: ['phone', 'auth_app'],
          },
        }

        expect(response).to redirect_to phone_setup_url
      end
    end

    context 'when multi selection with auth app first' do
      it 'redirects properly' do
        stub_sign_in_before_2fa
        patch :create, params: {
          two_factor_options_form: {
            selection: ['auth_app', 'phone', 'webauthn'],
          },
        }

        expect(response).to redirect_to authenticator_setup_url
      end
    end

    context 'when the selection is auth_app' do
      it 'redirects to authentication app setup page' do
        stub_sign_in_before_2fa

        patch :create, params: {
          two_factor_options_form: {
            selection: ['auth_app'],
          },
        }

        expect(response).to redirect_to authenticator_setup_url
      end
    end

    context 'when the selection is webauthn' do
      it 'redirects to webauthn setup page' do
        stub_sign_in_before_2fa

        patch :create, params: {
          two_factor_options_form: {
            selection: ['webauthn'],
          },
        }

        expect(response).to redirect_to webauthn_setup_url
      end
    end

    context 'when the selection is webauthn platform authenticator' do
      it 'redirects to webauthn setup page with the platform param' do
        stub_sign_in_before_2fa

        patch :create, params: {
          two_factor_options_form: {
            selection: ['webauthn_platform'],
          },
        }

        expect(response).to redirect_to webauthn_setup_url(platform: true)
      end
    end

    context 'when the selection is piv_cac' do
      it 'redirects to piv/cac setup page' do
        stub_sign_in_before_2fa

        patch :create, params: {
          two_factor_options_form: {
            selection: ['piv_cac'],
          },
        }

        expect(response).to redirect_to setup_piv_cac_url
      end
    end

    context 'when the selection is not valid' do
      it 'renders index page' do
        stub_sign_in_before_2fa

        patch :create, params: {
          two_factor_options_form: {
            selection: ['foo'],
          },
        }

        expect(response).to render_template(:index)
      end
    end
  end
end
