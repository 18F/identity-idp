require 'rails_helper'

describe ResetUserPasswordAndSendEmail do
  context 'when the user exists in the DB' do
    it "resets the user's password and sends an email" do
      allow(Kernel).to receive(:puts)

      email = 'test@test.com'
      user = create(:user, email: email)
      old_password = user.encrypted_password_digest
      subject = ResetUserPasswordAndSendEmail.new(user_emails: 'test@test.com')

      mailer = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
      allow(UserMailer).to receive(:please_reset_password).
        with(user.email_addresses.first).and_return(mailer)

      expect(mailer).to receive(:deliver_now)

      subject.call
      user.reload

      expect(user.encrypted_password_digest).to_not eq old_password
    end
  end

  context 'when the user does not exist in the DB' do
    it "does not attempt to reset the user's password nor send an email" do
      affected_email = 'test@test.com'
      not_affected_email = 'not_affected@test.com'
      user = create(:user, email: not_affected_email)
      old_password = user.encrypted_password_digest
      subject = ResetUserPasswordAndSendEmail.new(user_emails: affected_email)

      expect(UserMailer).to_not receive(:please_reset_password)
      expect(Kernel).to receive(:puts).with("user with email #{affected_email} not found")

      subject.call
      user.reload

      expect(user.encrypted_password_digest).to eq old_password
    end
  end
end
