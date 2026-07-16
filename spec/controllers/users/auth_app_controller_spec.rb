require 'rails_helper'

RSpec.describe Users::AuthAppController do
  let(:user) { create(:user, :with_phone) }
  let(:configuration) { create(:auth_app_configuration, user: user) }

  before do
    stub_analytics
    stub_sign_in(user) if user
  end

  describe '#confirm_delete' do
    let(:params) { { id: configuration.id } }
    let(:response) { get :confirm_delete, params: params }

    it 'assigns the form and renders the confirm delete page' do
      expect(response).to render_template(:confirm_delete)
      expect(assigns(:form)).to be_kind_of(TwoFactorAuthentication::AuthAppUpdateForm)
      expect(assigns(:form).configuration).to eq(configuration)
    end

    context 'signed out' do
      let(:user) { nil }
      let(:configuration) { create(:auth_app_configuration) }

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

    context 'confirming deletion of a configuration that does not exist' do
      let(:params) { { id: 0 } }

      it 'renders not found' do
        expect(response).to be_not_found
      end
    end

    context 'confirming deletion of a configuration that does not belong to the user' do
      let(:configuration) { create(:auth_app_configuration) }

      it 'renders not found' do
        expect(response).to be_not_found
      end
    end
  end
end
