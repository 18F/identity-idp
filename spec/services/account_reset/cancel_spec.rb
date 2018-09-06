require 'rails_helper'

describe AccountReset::Cancel do
  include AccountResetHelper

  let(:user) { create(:user, :signed_up) }

  before { TwilioService::Utils.telephony_service = FakeSms }

  it 'validates presence of token' do
    request = AccountReset::Cancel.new(nil).call

    expect(request.success?).to eq false
  end

  it 'validates validity of token' do
    request = AccountReset::Cancel.new('foo').call

    expect(request.success?).to eq false
  end

  context 'when the token is valid' do
    context 'when the user has a phone enabled for SMS' do
      before(:each) do
        user.mfa.phone_configurations.first.update!(delivery_preference: :sms)
      end

      it 'notifies the user via SMS of the account reset cancellation' do
        token = create_account_reset_request_for(user)
        allow(SmsAccountResetCancellationNotifierJob).to receive(:perform_now)

        AccountReset::Cancel.new(token).call

        expect(SmsAccountResetCancellationNotifierJob).
          to have_received(:perform_now).with(phone: user.mfa.phone_configurations.first.phone)
      end
    end

    context 'when the user does not have a phone enabled for SMS' do
      it 'does not notify the user via SMS' do
        token = create_account_reset_request_for(user)
        allow(SmsAccountResetCancellationNotifierJob).to receive(:perform_now)
        user.mfa.phone_configurations.clear

        AccountReset::Cancel.new(token).call

        expect(SmsAccountResetCancellationNotifierJob).to_not have_received(:perform_now)
      end
    end

    it 'notifies the user via email of the account reset cancellation' do
      token = create_account_reset_request_for(user)

      @mailer = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
      expect(UserMailer).to receive(:account_reset_cancel).with(user.email).
        and_return(@mailer)

      AccountReset::Cancel.new(token).call
    end

    it 'updates the account_reset_request' do
      token = create_account_reset_request_for(user)
      account_reset_request = AccountResetRequest.find_by(user_id: user.id)

      AccountReset::Cancel.new(token).call
      account_reset_request.reload

      expect(account_reset_request.request_token).to_not be_present
      expect(account_reset_request.granted_token).to_not be_present
      expect(account_reset_request.requested_at).to be_present
      expect(account_reset_request.cancelled_at).to be_present
    end
  end

  context 'when the token is not valid' do
    context 'when the user has a phone enabled for SMS' do
      it 'does not notify the user via SMS of the account reset cancellation' do
        allow(SmsAccountResetCancellationNotifierJob).to receive(:perform_now)

        AccountReset::Cancel.new('foo').call

        expect(SmsAccountResetCancellationNotifierJob).to_not have_received(:perform_now)
      end
    end

    context 'when the user does not have a phone enabled for SMS' do
      it 'does not notify the user via SMS' do
        allow(SmsAccountResetCancellationNotifierJob).to receive(:perform_now)
        user.mfa.phone_configurations.first.update!(mfa_enabled: false)

        AccountReset::Cancel.new('foo').call

        expect(SmsAccountResetCancellationNotifierJob).to_not have_received(:perform_now)
      end
    end

    it 'does not notify the user via email of the account reset cancellation' do
      expect(UserMailer).to_not receive(:account_reset_cancel)

      AccountReset::Cancel.new('foo').call
    end

    it 'does not update the account_reset_request' do
      create_account_reset_request_for(user)
      account_reset_request = AccountResetRequest.find_by(user_id: user.id)

      AccountReset::Cancel.new('foo').call
      account_reset_request.reload

      expect(account_reset_request.request_token).to be_present
      expect(account_reset_request.granted_token).to_not be_present
      expect(account_reset_request.requested_at).to be_present
      expect(account_reset_request.cancelled_at).to_not be_present
    end
  end
end
