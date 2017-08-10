require 'rails_helper'

describe ReauthnRequiredController do
  let(:user) { create(:user, :signed_up, email: 'old_email@example.com') }

  describe '#confirm_recently_authenticated' do
    controller do
      def show
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      routes.draw do
        get 'show' => 'reauthn_required#show'
      end
    end

    context 'recently authenticated' do
      it 'allows action' do
        get :show

        expect(response.body).to eq 'Hello'
      end
    end

    context 'authenticated outside the authn window' do
      before do
        controller.user_session[:authn_at] -= Figaro.env.reauthn_window.to_i
      end

      it 'redirects to password confirmation' do
        get :show

        expect(response).to redirect_to user_password_confirm_url
      end

      it 'sets context to authentication' do
        get :show

        expect(controller.user_session[:context]).to eq 'reauthentication'
      end
    end
  end
end
