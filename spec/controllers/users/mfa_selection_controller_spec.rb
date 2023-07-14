require 'rails_helper'

RSpec.describe Users::MfaSelectionController do
  let(:current_sp) { create(:service_provider) }

  describe '#index' do
    before do
      user = build(:user, :fully_registered)
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

  describe '#update' do
    it 'submits the TwoFactorOptionsForm' do
      user = build(:user)
      stub_sign_in(user)

      voice_params = {
        two_factor_options_form: {
          selection: 'voice',
        },
      }

      expect(controller.two_factor_options_form).to receive(:submit).
        with(hash_including(voice_params[:two_factor_options_form])).
        and_call_original

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

    context 'when the form is empty' do
      let(:user) { build(:user, :fully_registered) }

      before do
        stub_sign_in(user)
      end

      context 'with no active MFA' do
        it 'redirects to the index page with a flash error' do
          patch :update, params: {
            two_factor_options_form: {},
          }

          expect(response).to redirect_to two_factor_options_path
          expect(flash[:error]).to eq(
            t('errors.two_factor_auth_setup.must_select_option'),
          )
        end
      end

      context 'with an active MFA' do
        it 'redirects to after_mfa_setup_path' do
          create(:phone_configuration, user: user)

          patch :update, params: {
            two_factor_options_form: {
              selection: [''],
            },
          }

          expect(response).to redirect_to account_path
        end
      end
    end

    context 'when the selection is not valid' do
      it 'renders the index page' do
        stub_sign_in

        patch :update, params: {
          two_factor_options_form: {
            selection: 'foo',
          },
        }

        expect(response).to redirect_to second_mfa_setup_path
      end
    end
  end
end
