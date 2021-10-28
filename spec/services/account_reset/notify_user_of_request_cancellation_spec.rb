require 'rails_helper'

describe AccountReset::NotifyUserOfRequestCancellation do
  let(:user) { create(:user) }

  subject { described_class.new(user) }

  describe '#call' do
    it 'sends an email to all of the user email addresses' do
      email_address1 = user.email_addresses.first
      email_address2 = create(:email_address, user: user)

      mail1 = double
      mail2 = double

      expect(UserMailer).to receive(:account_reset_cancel).
        with(user, email_address1).and_return(mail1)
      expect(UserMailer).to receive(:account_reset_cancel).
        with(user, email_address2).and_return(mail2)

      expect(mail1).to receive(:deliver_now_or_later)
      expect(mail2).to receive(:deliver_now_or_later)

      subject.call
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
