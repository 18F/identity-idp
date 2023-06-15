require 'rails_helper'

RSpec.describe ReauthenticationRequiredConcern, type: :controller do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }

  describe '#confirm_recently_authenticated' do
    controller ApplicationController do
      include ReauthenticationRequiredConcern

      before_action :confirm_recently_authenticated

      def index
        render plain: 'Hello'
      end
    end

    before(:each) do
      stub_sign_in(user)
      allow(IdentityConfig.store).to receive(
        :reauthentication_for_second_factor_management_enabled,
      ).and_return(false)
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

  describe '#confirm_recently_authenticated_2fa' do
    controller ApplicationController do
      include ReauthenticationRequiredConcern

      before_action :confirm_recently_authenticated_2fa

      def index
        render plain: 'Hello'
      end
    end

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

      it 'redirects to 2FA options' do
        get :index

        expect(response).to redirect_to login_two_factor_options_url(reauthn: true)
      end

      it 'sets context to authentication' do
        get :index

        expect(controller.user_session[:context]).to eq 'reauthentication'
      end

      it 'records analytics' do
        controller.user_session[:auth_method] = TwoFactorAuthenticatable::AuthMethod::TOTP
        stub_analytics
        expect(@analytics).to receive(:track_event).with(
          'User 2FA Reauthentication Required',
          authenticated_at: controller.user_session[:authn_at],
          auth_method: 'totp',
        )
        get :index
      end
    end
  end
end
