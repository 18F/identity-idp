require 'rails_helper'

RSpec.describe AccountReset::GrantRequest do
  include AccountResetHelper

  let(:user) { create(:user) }
  let(:user2) { create(:user) }

  describe '#call' do
    it 'adds a notified at timestamp and granted token to the user' do
      create_account_reset_request_for(user)

      result = AccountReset::GrantRequest.new(user).call
      arr = AccountResetRequest.find_by(user_id: user.id)
      expect(arr.granted_at).to be_present
      expect(arr.granted_token).to be_present
      expect(result).to eq true
    end

    context 'with a currently valid token' do
      it 'returns false and does not update the request' do
        create_account_reset_request_for(user)
        AccountReset::GrantRequest.new(user).call

        arr = AccountResetRequest.find_by(user_id: user.id)
        result = AccountReset::GrantRequest.new(user).call
        expect(result).to eq false
        expect(arr.granted_at).to eq(arr.reload.granted_at)
        expect(arr.granted_token).to eq(arr.reload.granted_token)
      end
    end

    context 'with a fraud user' do
      let(:user) { create(:user, :fraud_review_pending) }
      let(:user2) { create(:user, :fraud_rejection) }
      context 'with nil being set for fraud time' do
        before do
          allow(IdentityConfig.store).to receive(:account_reset_fraud_user_wait_period_days)
            .and_return(nil)
        end

        it 'grants request for all users' do
          before_waiting_the_full_wait_period(Time.zone.now) do
            create_account_reset_request_for(user)
            create_account_reset_request_for(user2)
          end

          result = AccountReset::GrantRequest.new(user).call
          arr = AccountResetRequest.find_by(user_id: user.id)
          expect(arr.granted_at).to be_present
          expect(arr.granted_token).to be_present
          expect(result).to eq true

          result2 = AccountReset::GrantRequest.new(user2).call
          arr2 = AccountResetRequest.find_by(user_id: user2.id)
          expect(arr2.granted_at).to be_present
          expect(arr2.granted_token).to be_present
          expect(result2).to eq true
        end
      end
      context 'with deletion period not met' do
        it 'does not grant request' do
          create_account_reset_request_for(user)
          result = AccountReset::GrantRequest.new(user).call

          arr = AccountResetRequest.find_by(user_id: user.id)
          expect(arr.granted_at).to_not be_present
          expect(arr.granted_token).to_not be_present
          expect(result).to eq false
        end
      end

      context 'with deletion period met' do
        it 'grants request for all users' do
          before_waiting_the_full_fraud_wait_period(Time.zone.now) do
            create_account_reset_request_for(user)
            create_account_reset_request_for(user2)
          end

          result = AccountReset::GrantRequest.new(user).call
          arr = AccountResetRequest.find_by(user_id: user.id)
          expect(arr.granted_at).to be_present
          expect(arr.granted_token).to be_present
          expect(result).to eq true

          result2 = AccountReset::GrantRequest.new(user2).call
          arr2 = AccountResetRequest.find_by(user_id: user2.id)
          expect(arr2.granted_at).to be_present
          expect(arr2.granted_token).to be_present
          expect(result2).to eq true
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
