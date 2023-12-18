require 'rails_helper'

RSpec.describe Users::WebauthnController do
  let(:user) { create(:user, :with_phone) }
  let(:configuration) { create(:webauthn_configuration, user:) }

  before do
    stub_analytics
    stub_sign_in(user) if user
  end

  describe '#edit' do
    let(:params) { { id: configuration.id } }
    let(:response) { get :edit, params: params }

    it 'assigns the form instance' do
      response

      expect(assigns(:form)).to be_kind_of(TwoFactorAuthentication::WebauthnUpdateForm)
      expect(assigns(:form).configuration).to eq(configuration)
    end

    context 'signed out' do
      let(:user) { nil }
      let(:configuration) { create(:webauthn_configuration) }

      it 'redirects to sign-in page' do
        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'not recently authenticated' do
      before do
        allow(controller).to receive(:recently_authenticated_2fa?).and_return(false)
      end

      it 'redirects to reauthenticate' do
        expect(response).to redirect_to(login_two_factor_options_path)
      end
    end

    context 'editing a configuration that does not exist' do
      let(:params) { { id: 0 } }

      it 'renders not found' do
        expect(response).to be_not_found
      end
    end

    context 'editing a configuration that does not belong to the user' do
      let(:configuration) { create(:webauthn_configuration) }

      it 'renders not found' do
        expect(response).to be_not_found
      end
    end
  end

  describe '#update' do
    let(:name) { 'example' }
    let(:params) { { id: configuration.id, form: { name: } } }
    let(:response) { put :update, params: params }

    it 'redirects to account page with success message' do
      expect(response).to redirect_to(account_path)
      expect(flash[:success]).to eq(t('two_factor_authentication.webauthn_platform.renamed'))
    end

    it 'assigns the form instance' do
      response

      expect(assigns(:form)).to be_kind_of(TwoFactorAuthentication::WebauthnUpdateForm)
      expect(assigns(:form).configuration).to eq(configuration)
    end

    it 'logs the submission attempt' do
      response

      expect(@analytics).to have_logged_event(
        :webauthn_update_name_submitted,
        success: true,
        configuration_id: configuration.id.to_s,
        error_details: nil,
      )
    end

    context 'signed out' do
      let(:user) { nil }
      let(:configuration) { create(:webauthn_configuration) }

      it 'redirects to sign-in page' do
        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'with invalid submission' do
      let(:name) { '' }

      it 'renders edit template with error' do
        expect(response).to render_template(:edit)
        expect(flash.now[:error]).to eq(t('errors.messages.blank'))
      end

      it 'logs the submission attempt' do
        response

        expect(@analytics).to have_logged_event(
          :webauthn_update_name_submitted,
          success: false,
          configuration_id: configuration.id.to_s,
          error_details: { name: { blank: true } },
        )
      end
    end

    context 'not recently authenticated' do
      before do
        allow(controller).to receive(:recently_authenticated_2fa?).and_return(false)
      end

      it 'redirects to reauthenticate' do
        expect(response).to redirect_to(login_two_factor_options_path)
      end
    end
  end

  describe '#destroy' do
    let(:params) { { id: configuration.id } }
    let(:response) { delete :destroy, params: params }

    it 'responds with successful result' do
      expect(response).to redirect_to(account_path)
      expect(flash[:success]).to eq(t('two_factor_authentication.webauthn_platform.deleted'))
    end

    it 'logs the submission attempt' do
      response

      expect(@analytics).to have_logged_event(
        :webauthn_delete_submitted,
        success: true,
        configuration_id: configuration.id.to_s,
        error_details: nil,
      )
    end

    it 'assigns the form instance' do
      response

      expect(assigns(:form)).to be_kind_of(TwoFactorAuthentication::WebauthnDeleteForm)
      expect(assigns(:form).configuration).to eq(configuration)
    end

    context 'signed out' do
      let(:user) { nil }
      let(:configuration) { create(:webauthn_configuration) }

      it 'redirects to sign-in page' do
        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'with invalid submission' do
      let(:user) { create(:user) }

      it 'redirects to edit with unsuccessful result' do
        expect(response).to redirect_to(edit_webauthn_path(id: configuration.id))
        expect(flash[:error]).to eq(t('errors.manage_authenticator.remove_only_method_error'))
      end

      it 'logs the submission attempt' do
        response

        expect(@analytics).to have_logged_event(
          :webauthn_delete_submitted,
          success: false,
          configuration_id: configuration.id.to_s,
          error_details: { configuration_id: { only_method: true } },
        )
      end
    end

    context 'not recently authenticated' do
      before do
        allow(controller).to receive(:recently_authenticated_2fa?).and_return(false)
      end

      it 'redirects to reauthenticate' do
        expect(response).to redirect_to(login_two_factor_options_path)
      end
    end
  end
end
