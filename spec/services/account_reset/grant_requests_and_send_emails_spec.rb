require 'rails_helper'

describe AccountReset::GrantRequestsAndSendEmails do
  include AccountResetHelper

  let(:user) { create(:user) }
  let(:user2) { create(:user) }

  describe '#perform' do
    let(:now) { Time.zone.now }

    context 'after waiting the full wait period' do
      it 'does not send notifications when the notifications were already sent' do
        before_waiting_the_full_wait_period(now) do
          create_account_reset_request_for(user)
        end

        AccountReset::GrantRequestsAndSendEmails.new.perform(now)
        notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)
        expect(notifications_sent).to eq(0)
      end

      it 'does not send notifications when the request was cancelled' do
        before_waiting_the_full_wait_period(now) do
          create_account_reset_request_for(user)
          cancel_request_for(user)
        end

        notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)
        expect(notifications_sent).to eq(0)
      end

      it 'sends notifications after a request is granted' do
        before_waiting_the_full_wait_period(now) do
          create_account_reset_request_for(user)
        end

        notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)

        expect(notifications_sent).to eq(1)
      end

      it 'sends 2 notifications after 2 requests are granted' do
        before_waiting_the_full_wait_period(now) do
          create_account_reset_request_for(user)
          create_account_reset_request_for(user2)
        end

        notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)

        expect(notifications_sent).to eq(2)
      end
    end

    context 'after not waiting the full wait period' do
      it 'does not send notifications after a request' do
        create_account_reset_request_for(user)

        notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)
        expect(notifications_sent).to eq(0)
      end

      it 'does not send notifications when the request was cancelled' do
        create_account_reset_request_for(user)
        cancel_request_for(user)

        notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)
        expect(notifications_sent).to eq(0)
      end
    end
  end

  def before_waiting_the_full_wait_period(now)
    days = IdentityConfig.store.account_reset_wait_period_days.days
    travel_to(now - 1 - days) do
      yield
    end
  end
end
