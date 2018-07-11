require 'rails_helper'

describe AccountReset::CancelController do
  describe '#cancel' do
    it 'logs a good token to the analytics' do
      user = create(:user)
      AccountResetService.new(user).create_request

      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, event: :cancel, token_valid: true)

      post :cancel, params: { token: AccountResetRequest.all[0].request_token }
    end

    it 'logs a bad token to the analytics' do
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, event: :cancel, token_valid: false)

      post :cancel, params: { token: 'FOO' }
    end

    it 'redirects to the root' do
      post :cancel
      expect(response).to redirect_to root_url
    end
  end
end
