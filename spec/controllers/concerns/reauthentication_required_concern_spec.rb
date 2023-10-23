require 'rails_helper'

RSpec.describe ReauthenticationRequiredConcern, type: :controller do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }

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
      let(:travel_time) { (IdentityConfig.store.reauthn_window + 1).seconds }

      before do
        controller.auth_methods_session.authenticate!(TwoFactorAuthenticatable::AuthMethod::TOTP)
        travel travel_time
      end

      around do |example|
        freeze_time { example.run }
      end

      it 'redirects to 2FA options' do
        get :index

        expect(response).to redirect_to login_two_factor_options_url
      end

      it 'sets context to authentication' do
        get :index

        expect(controller.user_session[:context]).to eq 'reauthentication'
      end

      it 'records analytics' do
        stub_analytics
        expect(@analytics).to receive(:track_event).with(
          'User 2FA Reauthentication Required',
          authenticated_at: travel_time.ago,
          auth_method: TwoFactorAuthenticatable::AuthMethod::TOTP,
        )
        get :index
      end
    end
  end
end
