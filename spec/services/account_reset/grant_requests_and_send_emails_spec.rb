require 'rails_helper'

describe AccountReset::GrantRequestsAndSendEmails do
  include AccountResetHelper

  let(:user) { create(:user) }
  let(:user2) { create(:user) }

  describe '#call' do
    context 'after waiting the full wait period' do
      it 'does not send notifications when the notifications were already sent' do
        create_account_reset_request_for(user)

        after_waiting_the_full_wait_period do
          AccountReset::GrantRequestsAndSendEmails.new.call
          notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.call
          expect(notifications_sent).to eq(0)
        end
      end

      it 'does not send notifications when the request was cancelled' do
        create_account_reset_request_for(user)
        cancel_request_for(user)

        after_waiting_the_full_wait_period do
          notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.call
          expect(notifications_sent).to eq(0)
        end
      end

      it 'sends notifications after a request is granted' do
        create_account_reset_request_for(user)

        after_waiting_the_full_wait_period do
          notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.call

          expect(notifications_sent).to eq(1)
        end
      end

      it 'sends 2 notifications after 2 requests are granted' do
        create_account_reset_request_for(user)
        create_account_reset_request_for(user2)

        after_waiting_the_full_wait_period do
          notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.call

          expect(notifications_sent).to eq(2)
        end
      end
    end

    context 'after not waiting the full wait period' do
      it 'does not send notifications after a request' do
        create_account_reset_request_for(user)

        notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.call
        expect(notifications_sent).to eq(0)
      end

      it 'does not send notifications when the request was cancelled' do
        create_account_reset_request_for(user)
        cancel_request_for(user)

        notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.call
        expect(notifications_sent).to eq(0)
      end
    end
  end

  def after_waiting_the_full_wait_period
    days = Figaro.env.account_reset_wait_period_days.to_i.days
    Timecop.travel(Time.zone.now + days) do
      yield
    end
  end
end
