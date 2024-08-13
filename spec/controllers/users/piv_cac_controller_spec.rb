require 'rails_helper'

RSpec.describe Users::PivCacController do
  let(:user) { create(:user, :with_phone) }
  let(:configuration) { create(:piv_cac_configuration, user: user) }
  let(:presenter) { TwoFactorAuthentication::PivCacEditPresenter.new }

  before do
    stub_analytics
    stub_sign_in(user) if user
  end

  describe '#edit' do
    let(:params) { { id: configuration.id } }
    let(:response) { get :edit, params: params }

    it 'assigns the form instance' do
      response

      expect(assigns(:form)).to be_kind_of(TwoFactorAuthentication::PivCacUpdateForm)
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
      let(:configuration) { create(:piv_cac_configuration) }

      it 'renders not found' do
        expect(response).to be_not_found
      end
    end
  end

  describe '#update' do
    let(:name) { 'example' }
    let(:params) { { id: configuration.id, form: { name: name } } }
    let(:response) { put :update, params: params }

    it 'redirects to account page with success message' do
      expect(response).to redirect_to(account_path)
      expect(flash[:success]).to eq(presenter.rename_success_alert_text)
    end

    it 'logs the submission attempt' do
      response

      expect(@analytics).to have_logged_event(
        :piv_cac_update_name_submitted,
        success: true,
        configuration_id: configuration.id.to_s,
      )
    end

    it 'assigns the form instance' do
      response

      expect(assigns(:form)).to be_kind_of(TwoFactorAuthentication::PivCacUpdateForm)
      expect(assigns(:form).configuration).to eq(configuration)
    end

    context 'signed out' do
      let(:user) { nil }
      let(:configuration) { create(:piv_cac_configuration) }

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
    end

    context 'not recently authenticated' do
      before do
        allow(controller).to receive(:recently_authenticated_2fa?).and_return(false)
      end

      it 'redirects to reauthenticate' do
        expect(response).to redirect_to(login_two_factor_options_path)
      end
    end

    context 'with a configuration that does not exist' do
      let(:params) { { id: 0 } }

      it 'renders not found' do
        expect(response).to be_not_found
      end
    end

    context 'with a configuration that does not belong to the user' do
      let(:configuration) { create(:piv_cac_configuration) }

      it 'renders not found' do
        expect(response).to be_not_found
      end
    end
  end

  describe '#destroy' do
    let(:params) { { id: configuration.id } }
    let(:response) { delete :destroy, params: params }

    it 'responds with successful result' do
      expect(response).to redirect_to(account_path)
      expect(flash[:success]).to eq(presenter.delete_success_alert_text)
    end

    it 'removes the piv/cac information from the user session' do
      controller.user_session[:decrypted_x509] = {}
      response
      expect(controller.user_session[:decrypted_x509]).to be_nil
    end

    it 'logs the submission attempt' do
      response

      expect(@analytics).to have_logged_event(
        :piv_cac_delete_submitted,
        success: true,
        configuration_id: configuration.id.to_s,
      )
    end

    it 'assigns the form instance' do
      response

      expect(assigns(:form)).to be_kind_of(TwoFactorAuthentication::PivCacDeleteForm)
      expect(assigns(:form).configuration).to eq(configuration)
    end

    context 'signed out' do
      let(:user) { nil }
      let(:configuration) { create(:piv_cac_configuration) }

      it 'redirects to sign-in page' do
        expect(response).to redirect_to(new_user_session_url)
      end
    end

    context 'with invalid submission' do
      let(:user) { create(:user) }

      it 'redirects to edit with unsuccessful result' do
        expect(response).to redirect_to(edit_piv_cac_path(id: configuration.id))
        expect(flash[:error]).to eq(t('errors.manage_authenticator.remove_only_method_error'))
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

    context 'with a configuration that does not exist' do
      let(:params) { { id: 0 } }

      it 'renders not found' do
        expect(response).to be_not_found
      end
    end

    context 'with a configuration that does not belong to the user' do
      let(:configuration) { create(:piv_cac_configuration) }

      it 'renders not found' do
        expect(response).to be_not_found
      end
    end
  end
end
