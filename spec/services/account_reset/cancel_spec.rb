require 'rails_helper'

describe AccountReset::Cancel do
  include AccountResetHelper

  let(:user) { create(:user, :signed_up) }

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
        MfaContext.new(user).phone_configurations.first.update!(delivery_preference: :sms)
      end

      it 'notifies the user via SMS of the account reset cancellation' do
        token = create_account_reset_request_for(user)
        allow(Telephony).to receive(:perform_now)

        AccountReset::Cancel.new(token).call

        expect(Telephony::Test::Message.messages.last.body).to eq(
          I18n.t('telephony.account_reset_cancellation_notice', app_name: APP_NAME),
        )
      end

      it 'returns a FormResponse with message_id' do
        token = create_account_reset_request_for(user)

        response = AccountReset::Cancel.new(token).call

        expect(response.to_h[:message_id]).to be_present
      end
    end

    context 'when the user does not have a phone enabled for SMS' do
      it 'does not notify the user via SMS' do
        token = create_account_reset_request_for(user)
        MfaContext.new(user).phone_configurations.clear

        AccountReset::Cancel.new(token).call

        expect(Telephony::Test::Message.messages.length).to eq(0)
      end
    end

    it 'notifies the user via email of the account reset cancellation' do
      token = create_account_reset_request_for(user)
      AccountReset::Cancel.new(token).call

      expect_delivered_email_count(1)
      expect_delivered_email(
        to: [user.email_addresses.first.email],
        subject: t('user_mailer.account_reset_cancel.subject'),
      )
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
        AccountReset::Cancel.new('foo').call

        expect(Telephony::Test::Message.messages.length).to eq(0)
      end
    end

    context 'when the user does not have a phone enabled for SMS' do
      it 'does not notify the user via SMS' do
        MfaContext.new(user).phone_configurations.first.update!(mfa_enabled: false)

        AccountReset::Cancel.new('foo').call

        expect(Telephony::Test::Message.messages.length).to eq(0)
      end
    end

    it 'does not notify the user via email of the account reset cancellation' do
      AccountReset::Cancel.new('foo').call
      expect_delivered_email_count(0)
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
