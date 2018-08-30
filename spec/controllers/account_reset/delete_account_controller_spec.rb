require 'rails_helper'

describe AccountReset::DeleteAccountController do
  include AccountResetHelper

  describe '#delete' do
    it 'logs a good token to the analytics' do
      user = create(:user)
      create_account_reset_request_for(user)
      AccountResetService.new(user).grant_request

      session[:granted_token] = AccountResetRequest.all[0].granted_token
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, event: :delete, token_valid: true, user_id: user.uuid)

      delete :delete
    end

    it 'logs a bad token to the analytics' do
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, event: :delete, token_valid: false)

      delete :delete, params: { token: 'FOO' }
    end

    it 'redirects to root if there is no token' do
      delete :delete

      expect(response).to redirect_to(root_url)
    end
  end

  describe '#show' do
    it 'prevents parameter leak' do
      user = create(:user)
      create_account_reset_request_for(user)
      AccountResetService.new(user).grant_request

      get :show, params: { token: AccountResetRequest.all[0].granted_token }

      expect(response).to redirect_to(account_reset_delete_account_url)
    end

    it 'redirects to root if the token is bad' do
      get :show, params: { token: 'FOO' }

      expect(response).to redirect_to(root_url)
    end

    it 'renders the page' do
      user = create(:user)
      create_account_reset_request_for(user)
      AccountResetService.new(user).grant_request
      session[:granted_token] = AccountResetRequest.all[0].granted_token

      get :show

      expect(response).to render_template(:show)
    end

    it 'displays a flash and redirects to root if the token is expired' do
      user = create(:user)
      create_account_reset_request_for(user)
      AccountResetService.new(user).grant_request

      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET,
             event: :delete, token_valid: true, expired: true, user_id: user.uuid)

      Timecop.travel(Time.zone.now + 2.days) do
        get :show, params: { token: AccountResetRequest.all[0].granted_token }
      end

      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to eq t('devise.two_factor_authentication.account_reset.link_expired')
    end
  end
end
