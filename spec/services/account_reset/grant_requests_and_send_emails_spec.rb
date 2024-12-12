require 'rails_helper'

RSpec.describe AccountReset::GrantRequestsAndSendEmails do
  include AccountResetHelper

  let(:user) { create(:user) }
  let(:user2) { create(:user) }

  describe '#perform' do
    let(:now) { Time.zone.now }

    context 'after waiting the full wait period' do
      context 'standard user' do
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

      context 'possible fraud user' do
        let(:user) { create(:user, :fraud_review_pending) }
        let(:user2) { create(:user, :fraud_rejection) }
        before do
          allow(IdentityConfig.store).to receive(:account_reset_fraud_user_wait_period_days)
            .and_return(10)
        end
        it 'does not send notifications when the notifications were already sent' do
          before_waiting_the_full_fraud_wait_period(now) do
            create_account_reset_request_for(user)
          end

          AccountReset::GrantRequestsAndSendEmails.new.perform(now)
          notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)
          expect(notifications_sent).to eq(0)
        end

        it 'does not send notifications when the request was cancelled' do
          before_waiting_the_full_fraud_wait_period(now) do
            create_account_reset_request_for(user)
            cancel_request_for(user)
          end

          notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)
          expect(notifications_sent).to eq(0)
        end

        it 'sends notifications after a request is granted' do
          before_waiting_the_full_fraud_wait_period(now) do
            create_account_reset_request_for(user)
          end

          notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)

          expect(notifications_sent).to eq(1)
        end

        it 'sends 2 notifications after 2 requests are granted' do
          before_waiting_the_full_fraud_wait_period(now) do
            create_account_reset_request_for(user)
            create_account_reset_request_for(user2)
          end

          notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)

          expect(notifications_sent).to eq(2)
        end
      end
    end

    context 'after not waiting the full wait period' do
      context 'standard user' do
        it 'does not send notifications before a request wait period is done' do
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

      context 'possible fraud user' do
        let(:user) { create(:user, :fraud_review_pending) }
        let(:user2) { create(:user, :fraud_rejection) }
        context 'with fraud wait period set' do
          it 'does not send notifications before a request wait period is done' do
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

          it 'should not send if its in between regular wait period and fraud wait period' do
            before_waiting_the_full_wait_period(now) do
              create_account_reset_request_for(user)
              create_account_reset_request_for(user2)
            end

            notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)

            expect(notifications_sent).to eq(0)
          end
        end

        context 'with fraud wait period not set' do
          before do
            allow(IdentityConfig.store).to receive(:account_reset_fraud_user_wait_period_days)
              .and_return(nil)
          end
          it 'does not send notifications before a request wait period is done' do
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

          it 'should send if its after regular wait period' do
            before_waiting_the_full_wait_period(now) do
              create_account_reset_request_for(user)
              create_account_reset_request_for(user2)
            end

            notifications_sent = AccountReset::GrantRequestsAndSendEmails.new.perform(now)

            expect(notifications_sent).to eq(2)
          end
        end
      end
    end
  end

  def before_waiting_the_full_wait_period(now)
    days = IdentityConfig.store.account_reset_wait_period_days.days
    travel_to(now - 1 - days) do
      yield
    end
  end

  def before_waiting_the_full_fraud_wait_period(now)
    days = IdentityConfig.store.account_reset_fraud_user_wait_period_days.days
    travel_to(now - 1 - days) do
      yield
    end
  end
end
