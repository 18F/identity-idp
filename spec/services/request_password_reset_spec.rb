require 'rails_helper'

describe RequestPasswordReset do
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

        RequestPasswordReset.new(email).perform
        user = User.find_with_email(email)
        expect(user).to be_present
        expect(RegistrationLog.first.user_id).to eq(user.id)
      end
    end

    context 'when the user is found and confirmed' do
      it 'sends password reset instructions' do
        user = create(:user)
        email = user.email_addresses.first.email

        allow(User).to receive(:find_with_email).with(email).and_return(user)

        expect(user).to receive(:set_reset_password_token).and_return('asdf1234')

        mail = double
        expect(mail).to receive(:deliver_now)
        expect(UserMailer).to receive(:reset_password_instructions).
          with(email, token: 'asdf1234').
          and_return(mail)

        RequestPasswordReset.new(email).perform
      end
    end

    context 'when the user is found, not privileged, and not yet confirmed' do
      it 'sends password reset instructions' do
        user = create(:user, :unconfirmed)
        email = user.email_addresses.first.email

        allow(User).to receive(:find_with_email).with(email).and_return(user)

        expect(user).to receive(:set_reset_password_token).and_return('asdf1234')

        mail = double
        expect(mail).to receive(:deliver_now)
        expect(UserMailer).to receive(:reset_password_instructions).
          with(email, token: 'asdf1234').
          and_return(mail)

        RequestPasswordReset.new(email).perform
      end
    end
  end
end
