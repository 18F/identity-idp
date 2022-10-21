require 'rails_helper'

describe Users::TwoFactorAuthenticationSetupController do
  describe 'GET index' do
    it 'tracks the visit in analytics' do
      stub_sign_in_before_2fa
      stub_analytics

      expect(@analytics).to receive(:track_event).
        with('User Registration: 2FA Setup visited')

      get :index
    end

    context 'when signed out' do
      it 'redirects to sign in page' do
        get :index

        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'when fully authenticated and MFA enabled' do
      it 'loads the account page' do
        user = build(:user, :signed_up)
        stub_sign_in(user)

        get :index

        expect(response).to redirect_to(account_url)
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
      it 'prompts for 2FA' do
        user = build(:user, :signed_up)
        stub_sign_in_before_2fa(user)

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
          selection: 'voice',
        },
      }
      params = ActionController::Parameters.new(voice_params)
      response = FormResponse.new(success: true, errors: {}, extra: { selection: ['voice'] })

      form_params = { user: user, phishing_resistant_required: false, piv_cac_required: nil }
      form = instance_double(TwoFactorOptionsForm)
      allow(TwoFactorOptionsForm).to receive(:new).with(form_params).and_return(form)
      expect(form).to receive(:submit).
        with(params.require(:two_factor_options_form).permit(:selection)).
        and_return(response)
      expect(form).to receive(:selection).twice.and_return(['voice'])

      patch :create, params: voice_params

      expect(@analytics).to have_logged_event('User Registration: 2FA Setup', response.to_h)
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

    context 'when the selection is only phone and multi mfa is enabled' do
      before do
        allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
        allow(IdentityConfig.store).to receive(:kantara_2fa_phone_restricted).and_return(true)
        stub_sign_in_before_2fa

        patch :create, params: {
          two_factor_options_form: {
            selection: 'phone',
          },
        }
      end

      it 'the redirect to the form page with an anchor' do
        expect(response).to redirect_to(authentication_methods_setup_path(anchor: 'select_phone'))
      end
      it 'contains a flash message' do
        expect(flash[:phone_error]).to eq(
          t('errors.two_factor_auth_setup.must_select_additional_option'),
        )
      end
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
            selection: 'auth_app',
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
            selection: 'webauthn',
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
            selection: 'webauthn_platform',
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
            selection: 'piv_cac',
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
            selection: 'foo',
          },
        }

        expect(response).to render_template(:index)
      end
    end
  end
end
