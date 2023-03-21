require 'rails_helper'

describe ReauthenticationRequiredConcern, type: :controller do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }

  controller ApplicationController do
    include ReauthenticationRequiredConcern

    before_action :confirm_recently_authenticated

    def index
      render plain: 'Hello'
    end
  end

  describe '#confirm_recently_authenticated' do
    before(:each) do
      stub_sign_in(user)
    end

    context 'recently authenticated' do
      it 'allows action' do
        get :index

        expect(response.body).to eq 'Hello'
      end
    end

    context 'authenticated outside the authn window' do
      before do
        controller.user_session[:authn_at] -= IdentityConfig.store.reauthn_window
      end

      it 'redirects to password confirmation' do
        get :index

        expect(response).to redirect_to user_password_confirm_url
      end

      it 'sets context to authentication' do
        get :index

        expect(controller.user_session[:context]).to eq 'reauthentication'
      end
    end
  end
end
