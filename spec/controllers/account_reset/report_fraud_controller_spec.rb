require 'rails_helper'

describe AccountReset::ReportFraudController do
  include AccountResetHelper

  describe '#update' do
    it 'logs a good token to the analytics' do
      user = create(:user)
      create_account_reset_request_for(user)

      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, event: :fraud, token_valid: true)

      post :update, params: { token: AccountResetRequest.all[0].request_token }
    end

    it 'logs a bad token to the analytics' do
      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET, event: :fraud, token_valid: false)

      post :update, params: { token: 'FOO' }
    end

    it 'redirects to the root' do
      post :update
      expect(response).to redirect_to root_url
    end
  end
end
