require 'rails_helper'

describe EmailNotifier do
  describe '#send_password_changed_email' do
    let(:mailer) { instance_double(ActionMailer::MessageDelivery) }

    context 'when the password has changed' do
      it 'sends an email notifiying the user of the password change' do
        user = create(:user, :signed_up, password: 'newValidPass!!00')

        expect(UserMailer).to receive(:password_changed).with(user).and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        EmailNotifier.new(user).send_password_changed_email
      end
    end
  end

  describe '#send_email_changed_email' do
    context 'when the email has not changed' do
      it 'does not send an email' do
        user = build_stubbed(:user, :signed_up)

        expect(UserMailer).to_not receive(:email_changed).with(user.email)

        EmailNotifier.new(user).send_email_changed_email
      end
    end

    context 'when the user has changed and confirmed their new email' do
      it 'notifies the old email address of the email change' do
        user = build(:user, :signed_up)
        old_email = user.email
        UpdateUser.new(user: user, attributes: { email: 'new@example.com' }).call
        user.confirm

        expect(UserMailer).to receive(:email_changed).with(old_email).and_return(mailer)
        expect(mailer).to receive(:deliver_later)

        EmailNotifier.new(user).send_email_changed_email
      end
    end
  end
end
