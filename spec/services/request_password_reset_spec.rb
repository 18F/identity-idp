require 'rails_helper'

describe RequestPasswordReset do
  let(:analytics) { FakeAnalytics.new }

  describe '#perform' do
    context 'when the user is not found' do
      it 'sends the account registration email' do
        email = 'nonexistent@example.com'

        send_sign_up_email_confirmation = instance_double(SendSignUpEmailConfirmation)
        expect(send_sign_up_email_confirmation).to receive(:call).with(
          hash_including(
            instructions: I18n.t(
              'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
            ),
          ),
        )
        expect(SendSignUpEmailConfirmation).to receive(:new).and_return(
          send_sign_up_email_confirmation,
        )

        RequestPasswordReset.new(email: email).perform
        user = User.find_with_email(email)
        expect(user).to be_present
        expect(RegistrationLog.first.user_id).to eq(user.id)
      end
    end

    context 'when the user is found and confirmed' do
      it 'sends password reset instructions' do
        user = create(:user)
        email_address = user.email_addresses.first
        email = email_address.email

        allow(EmailAddress).to receive(:find_with_email).with(email).and_return(email_address)

        expect(user).to receive(:set_reset_password_token).and_return('asdf1234')

        mail = double
        expect(mail).to receive(:deliver_now)
        expect(UserMailer).to receive(:reset_password_instructions).
          with(user, email, token: 'asdf1234').
          and_return(mail)

        RequestPasswordReset.new(email: email).perform
      end
    end

    context 'when the user is found, not privileged, and not yet confirmed' do
      it 'sends password reset instructions' do
        user = create(:user, :unconfirmed)
        email_address = user.email_addresses.first
        email = email_address.email

        allow(EmailAddress).to receive(:find_with_email).with(email).and_return(email_address)

        expect(user).to receive(:set_reset_password_token).and_return('asdf1234')

        mail = double
        expect(mail).to receive(:deliver_now)
        expect(UserMailer).to receive(:reset_password_instructions).
          with(user, email, token: 'asdf1234').
          and_return(mail)

        RequestPasswordReset.new(email: email).perform
      end
    end

    context 'when the user is found and confirmed, but the email address is not' do
      it 'sends the account registration email' do
        user = create(:user, :with_multiple_emails)
        unconfirmed_email_address = user.reload.email_addresses.last
        unconfirmed_email_address.update!(confirmed_at: nil)

        send_sign_up_email_confirmation = instance_double(SendSignUpEmailConfirmation)
        expect(send_sign_up_email_confirmation).to receive(:call).with(
          hash_including(
            instructions: I18n.t(
              'user_mailer.email_confirmation_instructions.first_sentence.forgot_password',
            ),
          ),
        )
        expect(SendSignUpEmailConfirmation).to receive(:new).and_return(
          send_sign_up_email_confirmation,
        )

        RequestPasswordReset.new(email: unconfirmed_email_address.email).perform
      end
    end

    context 'when two users have the same email address' do
      let(:email) { 'aaa@test.com' }

      before do
        @user_unconfirmed = create(:user, email: email, confirmed_at: nil)
        @user_confirmed = create(:user, email: email, confirmed_at: Time.zone.now)
      end

      around do |example|
        # make the test more deterministic
        EmailAddress.default_scopes = [-> { order('id ASC') }]
        example.run
        EmailAddress.default_scopes = []
      end

      it 'always finds the user with the confirmed email address' do
        form = RequestPasswordReset.new(email: email)
        form.perform

        expect(form.send(:user)).to eq(@user_confirmed)
      end
    end
  end
end
