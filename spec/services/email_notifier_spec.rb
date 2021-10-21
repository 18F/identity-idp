require 'rails_helper'

describe EmailNotifier do
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
        user = create(:user, :signed_up)
        old_email = user.email
        UpdateUser.new(user: user, attributes: { email: 'new@example.com' }).call

        expect(UserMailer).to receive(:email_changed).with(old_email).and_return(mailer)
        expect(mailer).to receive(:deliver_now_or_later)

        EmailNotifier.new(user).send_email_changed_email
      end
    end
  end
end
