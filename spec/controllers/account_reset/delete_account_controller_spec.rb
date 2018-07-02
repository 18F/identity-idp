require 'rails_helper'

describe AccountReset::DeleteAccountController do
  describe '#delete' do
    it 'logs a good token to the analytics' do
      user = create(:user)
      AccountResetService.new(user).create_request
      AccountResetService.new(user).grant_request

      session[:granted_token] = AccountResetRequest.all[0].granted_token
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, event: :delete, token_valid: true)

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
      AccountResetService.new(user).create_request
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
      AccountResetService.new(user).create_request
      AccountResetService.new(user).grant_request
      session[:granted_token] = AccountResetRequest.all[0].granted_token

      get :show

      expect(response).to render_template(:show)
    end
  end
end
