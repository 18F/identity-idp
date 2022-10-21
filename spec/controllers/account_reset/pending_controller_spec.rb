require 'rails_helper'

describe AccountReset::PendingController do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe '#show' do
    context 'when the account reset request does not exist' do
      it 'renders a 404' do
        get :show

        expect(response).to render_template('pages/page_not_found')
      end
    end
  end

  describe '#cancel' do
    it 'cancels the account reset request and logs the cancellation event' do
      stub_attempts_tracker

      account_reset_request = AccountResetRequest.create(user: user, requested_at: 1.hour.ago)

      expect(@irs_attempts_api_tracker).to receive(:track_event).
        with(:account_reset_cancel_request)

      post :cancel

      expect(account_reset_request.reload.cancelled_at).to_not be_nil
    end

    context 'when the account reset request does not exist' do
      it 'renders a 404' do
        post :cancel

        expect(response).to render_template('pages/page_not_found')
      end
    end
  end
end
