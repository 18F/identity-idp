require 'rails_helper'

describe UpdateUserPassword do
  let(:user) { User.new(password: 'old strong password') }
  let(:user_session) { {} }

  describe '#call' do
    context 'when the password is invalid' do
      it 'returns FormResponse with success: false and does not do anything else' do
        password = 'new'
        errors = {
          password: ['is too short (minimum is 8 characters)'],
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors).and_return(result)
        expect(UpdateUser).not_to receive(:new)
        expect(EmailNotifier).not_to receive(:new)
        expect(ActiveProfileEncryptor).not_to receive(:new)
        expect(UpdateUserPassword.new(user, user_session, password).call).to eq result
      end
    end

    context 'when the password is valid and the user has an active profile' do
      it 'returns FormResponse with success: true and performs additional actions' do
        password = 'salty new password'
        result = instance_double(FormResponse)
        user_updater = instance_double(UpdateUser)
        email_notifier = instance_double(EmailNotifier)
        encryptor = instance_double(ActiveProfileEncryptor)
        profile = build_stubbed(:profile, :active, :verified, pii: { ssn: '1234' })
        user = profile.user
        allow(user).to receive(:active_profile).and_return(profile)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}).and_return(result)
        expect(UpdateUser).to receive(:new).
          with(user: user, attributes: { password: 'salty new password' }).
          and_return(user_updater)
        expect(user_updater).to receive(:call)
        expect(EmailNotifier).to receive(:new).with(user).and_return(email_notifier)
        expect(email_notifier).to receive(:send_password_changed_email)
        expect(ActiveProfileEncryptor).to receive(:new).
          with(user, user_session, password).and_return(encryptor)
        expect(encryptor).to receive(:call)
        expect(UpdateUserPassword.new(user, user_session, password).call).to eq result
      end
    end

    context 'when the user does not have an active profile' do
      it 'does not call ActiveProfileEncryptor' do
        password = 'strong password'
        email_notifier = instance_double(EmailNotifier)

        expect(EmailNotifier).to receive(:new).with(user).and_return(email_notifier)
        expect(email_notifier).to receive(:send_password_changed_email)
        expect(ActiveProfileEncryptor).to_not receive(:new)

        UpdateUserPassword.new(user, user_session, password).call
      end
    end
  end
end
