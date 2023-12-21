require 'rails_helper'

RSpec.describe ReauthenticationRequiredConcern, type: :controller do
  let(:user) { create(:user, :fully_registered, email: 'old_email@example.com') }

  controller ApplicationController do
    include ReauthenticationRequiredConcern

    before_action :confirm_recently_authenticated_2fa

    def index
      render plain: 'Hello'
    end
  end

  before(:each) do
    stub_sign_in(user) if user
  end

  describe '#confirm_recently_authenticated_2fa' do
    context 'recently authenticated' do
      it 'allows action' do
        get :index

        expect(response.body).to eq 'Hello'
      end
    end

    context 'signed out' do
      let(:user) { nil }

      it 'redirects to 2FA options' do
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

  describe '#recently_authenticated_2fa?' do
    subject(:recently_authenticated_2fa) { controller.recently_authenticated_2fa? }

    context 'recently authenticated' do
      it { expect(recently_authenticated_2fa).to eq(true) }
    end

    context 'signed out' do
      let(:user) { nil }

      it { expect(recently_authenticated_2fa).to eq(false) }
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

      it { expect(recently_authenticated_2fa).to eq(false) }
    end
  end
end
