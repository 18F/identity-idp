require 'rails_helper'

describe Users::MfaSelectionController do
  let(:current_sp) { create(:service_provider) }
  before do
    allow(IdentityConfig.store).to receive(:select_multiple_mfa_options).and_return(true)
  end

  describe '#index' do
    before do
      user = build(:user, :signed_up)
      stub_sign_in(user)
    end

    context 'when the user is using one authenticator option' do
      it 'shows the mfa setup screen' do
        controller.user_session[:selected_mfa_options] = ['backup_code']

        get :index

        expect(response).to render_template(:index)
      end
    end
  end

  describe '#non_restricted' do
    before do
      allow(IdentityConfig.store).to receive(:kantara_2fa_phone_restricted).and_return(true)
      user = build(:user, :signed_up, :with_phone)
      stub_sign_in(user)
    end

    it 'shows the mfa setup screen' do
      get :non_restricted

      expect(response).to render_template(:index)
    end
  end

  describe '#update' do
    it 'submits the TwoFactorOptionsForm' do
      user = build(:user)
      stub_sign_in(user)

      voice_params = {
        two_factor_options_form: {
          selection: 'voice',
        },
      }
      params = ActionController::Parameters.new(voice_params)
      response = FormResponse.new(success: true, errors: {}, extra: { selection: ['voice'] })

      form = instance_double(TwoFactorOptionsForm)
      allow(TwoFactorOptionsForm).to receive(:new).with(user).and_return(form)
      expect(form).to receive(:submit).
        with(params.require(:two_factor_options_form).permit(:selection)).
        and_return(response)
      expect(form).to receive(:selection).and_return(['voice'])

      patch :update, params: voice_params
    end

    context 'when the selection is phone' do
      let(:user) do
        create(
          :user, :with_phone,
          with: { phone: '7035550000', confirmed_at: Time.zone.now }
        )
      end

      it 'redirects to phone setup page' do
        stub_sign_in(user)

        patch :update, params: {
          two_factor_options_form: {
            selection: 'phone',
          },
        }

        expect(response).to redirect_to phone_setup_url
      end
    end

    context 'when multi selection with phone first' do
      it 'redirects properly' do
        stub_sign_in_before_2fa
        patch :update, params: {
          two_factor_options_form: {
            selection: ['phone', 'auth_app'],
          },
        }

        expect(response).to redirect_to phone_setup_url
      end
    end

    context 'when multi selection with auth app first' do
      it 'redirects properly' do
        stub_sign_in
        patch :update, params: {
          two_factor_options_form: {
            selection: ['auth_app', 'phone', 'webauthn'],
          },
        }

        expect(response).to redirect_to authenticator_setup_url
      end
    end

    context 'when the selection is auth_app' do
      it 'redirects to authentication app setup page' do
        stub_sign_in

        patch :update, params: {
          two_factor_options_form: {
            selection: 'auth_app',
          },
        }

        expect(response).to redirect_to authenticator_setup_url
      end
    end

    context 'when the selection is webauthn' do
      it 'redirects to webauthn setup page' do
        stub_sign_in

        patch :update, params: {
          two_factor_options_form: {
            selection: 'webauthn',
          },
        }

        expect(response).to redirect_to webauthn_setup_url
      end
    end

    context 'when the selection is webauthn platform authenticator' do
      it 'redirects to webauthn setup page with the platform param' do
        stub_sign_in

        patch :update, params: {
          two_factor_options_form: {
            selection: 'webauthn_platform',
          },
        }

        expect(response).to redirect_to webauthn_setup_url(platform: true)
      end
    end

    context 'when the selection is piv_cac' do
      it 'redirects to piv/cac setup page' do
        stub_sign_in

        patch :update, params: {
          two_factor_options_form: {
            selection: 'piv_cac',
          },
        }

        expect(response).to redirect_to setup_piv_cac_url
      end
    end

    context 'when the selection is not valid' do
      it 'redirects to the index page' do
        stub_sign_in

        patch :update, params: {
          two_factor_options_form: {
            selection: 'foo',
          },
        }

        expect(response).to redirect_to two_factor_options_url(anchor: 'select_phone')
      end
    end
  end
end
