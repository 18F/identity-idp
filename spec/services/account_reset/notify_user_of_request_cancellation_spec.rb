require 'rails_helper'

describe AccountReset::NotifyUserOfRequestCancellation do
  let(:user) { create(:user) }

  subject { described_class.new(user) }

  describe '#call' do
    it 'sends an email to all of the user email addresses' do
      email_address1 = user.email_addresses.first
      email_address2 = create(:email_address, user: user)

      subject.call

      expect_delivered_email_count(2)
      expect_delivered_email(
        to: [email_address1.email],
        subject: t('user_mailer.account_reset_cancel.subject'),
      )
      expect_delivered_email(
        to: [email_address2.email],
        subject: t('user_mailer.account_reset_cancel.subject'),
      )
    end

    it 'sends a text to all of the user phone numbers' do
      phone_config1 = create(:phone_configuration, user: user)
      phone_config2 = create(:phone_configuration, user: user)

      expect(Telephony).to receive(:send_account_reset_cancellation_notice).
        with(to: phone_config1.phone, country_code: 'US')
      expect(Telephony).to receive(:send_account_reset_cancellation_notice).
        with(to: phone_config2.phone, country_code: 'US')

      subject.call
    end
  end
end
