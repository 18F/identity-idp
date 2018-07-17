require 'rails_helper'

describe AccountReset::CancelController do
  let(:user) { create(:user, :signed_up, phone: '+1 (703) 555-0000') }
  before do
    TwilioService::Utils.telephony_service = FakeSms
  end

  describe '#cancel' do
    it 'logs a good token to the analytics' do
      AccountResetService.new(user).create_request

      stub_analytics
      expect(@analytics).to receive(:track_event).
        with(Analytics::ACCOUNT_RESET,
             event: :cancel, token_valid: true, user_id: user.uuid)

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

    it 'sends an SMS if there is a phone' do
      AccountResetService.new(user).create_request
      allow(SmsAccountResetCancellationNotifierJob).to receive(:perform_now)

      post :cancel, params: { token: AccountResetRequest.all[0].request_token }

      expect(SmsAccountResetCancellationNotifierJob).to have_received(:perform_now).with(
        phone: user.phone
      )
    end

    it 'does not send an SMS if there is no phone' do
      AccountResetService.new(user).create_request
      allow(SmsAccountResetCancellationNotifierJob).to receive(:perform_now)
      user.phone = nil
      user.save!

      post :cancel, params: { token: AccountResetRequest.all[0].request_token }

      expect(SmsAccountResetCancellationNotifierJob).to_not have_received(:perform_now)
    end

    it 'sends an email' do
      AccountResetService.new(user).create_request

      @mailer = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
      allow(UserMailer).to receive(:account_reset_cancel).with(user.email).
        and_return(@mailer)

      post :cancel, params: { token: AccountResetRequest.all[0].request_token }
    end
  end
end
