require 'rails_helper'

describe AccountResetService do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let(:subject) { AccountResetService.new(user) }
  let(:user2) { create(:user) }
  let(:subject2) { AccountResetService.new(user2) }

  before do
    allow(Figaro.env).to receive(:account_reset_wait_period_days).and_return('1')
  end

  describe '#create_request' do
    it 'creates a new account reset request on the user' do
      subject.create_request
      arr = user.account_reset_request
      expect(arr.request_token).to be_present
      expect(arr.requested_at).to be_present
      expect(arr.cancelled_at).to be_nil
      expect(arr.granted_at).to be_nil
      expect(arr.granted_token).to be_nil
    end

    it 'creates a new account reset request in the db' do
      subject.create_request
      arr = AccountResetRequest.find_by(user_id: user.id)
      expect(arr.request_token).to be_present
      expect(arr.requested_at).to be_present
      expect(arr.cancelled_at).to be_nil
      expect(arr.granted_at).to be_nil
      expect(arr.granted_token).to be_nil
    end
  end

  describe '#cancel_request' do
    it 'removes tokens from a account reset request' do
      subject.create_request
      AccountResetService.cancel_request(user.account_reset_request.request_token)
      arr = AccountResetRequest.find_by(user_id: user.id)
      expect(arr.request_token).to_not be_present
      expect(arr.granted_token).to_not be_present
      expect(arr.requested_at).to be_present
      expect(arr.cancelled_at).to be_present
    end

    it 'does not raise an error for a cancel request with a blank token' do
      AccountResetService.cancel_request('')
    end

    it 'does not raise an error for a cancel request with a nil token' do
      AccountResetService.cancel_request('')
    end

    it 'does not raise an error for a cancel request with a bad token' do
      AccountResetService.cancel_request('ABC')
    end
  end

  describe '#report_fraud' do
    it 'removes tokens from the request' do
      subject.create_request
      AccountResetService.report_fraud(user.account_reset_request.request_token)
      arr = AccountResetRequest.find_by(user_id: user.id)
      expect(arr.request_token).to_not be_present
      expect(arr.granted_token).to_not be_present
      expect(arr.requested_at).to be_present
      expect(arr.cancelled_at).to be_present
      expect(arr.reported_fraud_at).to be_present
    end

    it 'does not raise an error for a fraud request with a blank token' do
      token_found = AccountResetService.report_fraud('')
      expect(token_found).to be(false)
    end

    it 'does not raise an error for a cancel request with a nil token' do
      token_found = AccountResetService.report_fraud('')
      expect(token_found).to be(false)
    end

    it 'does not raise an error for a cancel request with a bad token' do
      token_found = AccountResetService.report_fraud('ABC')
      expect(token_found).to be(false)
    end
  end

  describe '#grant_request' do
    it 'adds a notified at timestamp and granted token to the user' do
      rd = subject
      rd.create_request
      rd.grant_request
      arr = AccountResetRequest.find_by(user_id: user.id)
      expect(arr.granted_at).to be_present
      expect(arr.granted_token).to be_present
    end
  end

  describe '.grant_tokens_and_send_notifications' do
    context 'after waiting the full wait period' do
      it 'does not send notifications when the notifications were already sent' do
        subject.create_request

        after_waiting_the_full_wait_period do
          AccountResetService.grant_tokens_and_send_notifications
          notifications_sent = AccountResetService.grant_tokens_and_send_notifications
          expect(notifications_sent).to eq(0)
        end
      end

      it 'does not send notifications when the request was cancelled' do
        subject.create_request
        AccountResetService.cancel_request(AccountResetRequest.all[0].request_token)

        after_waiting_the_full_wait_period do
          notifications_sent = AccountResetService.grant_tokens_and_send_notifications
          expect(notifications_sent).to eq(0)
        end
      end

      it 'sends notifications after a request is granted' do
        subject.create_request

        after_waiting_the_full_wait_period do
          notifications_sent = AccountResetService.grant_tokens_and_send_notifications

          expect(notifications_sent).to eq(1)
        end
      end

      it 'sends 2 notifications after 2 requests are granted' do
        subject.create_request
        subject2.create_request

        after_waiting_the_full_wait_period do
          notifications_sent = AccountResetService.grant_tokens_and_send_notifications

          expect(notifications_sent).to eq(2)
        end
      end
    end

    context 'after not waiting the full wait period' do
      it 'does not send notifications after a request' do
        subject.create_request

        notifications_sent = AccountResetService.grant_tokens_and_send_notifications
        expect(notifications_sent).to eq(0)
      end

      it 'does not send notifications when the request was cancelled' do
        subject.create_request
        AccountResetService.cancel_request(AccountResetRequest.all[0].request_token)

        notifications_sent = AccountResetService.grant_tokens_and_send_notifications
        expect(notifications_sent).to eq(0)
      end
    end
  end

  def after_waiting_the_full_wait_period
    TwilioService.telephony_service = FakeSms
    days = Figaro.env.account_reset_wait_period_days.to_i.days
    Timecop.travel(Time.zone.now + days) do
      yield
    end
  end
end
