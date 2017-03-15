require 'rails_helper'

describe UpdateUserPassword do
  let(:user) { User.new(password: 'old strong password') }
  let(:user_session) { {} }
  let(:password) { 'salty new password' }
  let(:subject) do
    UpdateUserPassword.new(user: user, user_session: user_session, password: password)
  end

  describe '#call' do
    context 'when the password is invalid' do
      let(:password) { 'invalid' }

      it 'returns FormResponse with success: false and does not do anything else' do
        errors = {
          password: [t('errors.messages.too_short.other', count: Devise.password_length.first)],
        }
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: false, errors: errors).and_return(result)
        expect(UpdateUser).not_to receive(:new)
        expect(EmailNotifier).not_to receive(:new)
        expect(ActiveProfileEncryptor).not_to receive(:new)
        expect(subject.call).to eq result
      end
    end

    context 'when the password is valid' do
      it 'returns FormResponse with success: true' do
        stub_email_delivery

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}).and_return(result)
        expect(subject.call).to eq result
      end

      it 'updates the user' do
        stub_email_delivery

        user_updater = instance_double(UpdateUser)
        allow(UpdateUser).to receive(:new).
          with(user: user, attributes: { password: 'salty new password' }).
          and_return(user_updater)
        allow(user_updater).to receive(:call)

        subject.call

        expect(user_updater).to have_received(:call)
      end

      it 'sends an email to notify of the password change' do
        email_notifier = instance_double(EmailNotifier)
        allow(EmailNotifier).to receive(:new).with(user).and_return(email_notifier)
        allow(email_notifier).to receive(:send_password_changed_email)

        subject.call

        expect(email_notifier).to have_received(:send_password_changed_email)
      end
    end

    context 'when the user has an active profile' do
      let(:profile) { create(:profile, :active, :verified, pii: { ssn: '1234' }) }
      let(:user) { profile.user }

      it 'encrypts the active profile' do
        allow(user).to receive(:active_profile).and_return(profile)

        stub_email_delivery

        encryptor = instance_double(ActiveProfileEncryptor)
        allow(ActiveProfileEncryptor).to receive(:new).
          with(user, user_session, password).and_return(encryptor)
        allow(encryptor).to receive(:call)

        subject.call

        expect(encryptor).to have_received(:call)
      end
    end

    context 'when the user does not have an active profile' do
      it 'does not call ActiveProfileEncryptor' do
        email_notifier = instance_double(EmailNotifier)

        expect(EmailNotifier).to receive(:new).with(user).and_return(email_notifier)
        expect(email_notifier).to receive(:send_password_changed_email)
        expect(ActiveProfileEncryptor).to_not receive(:new)

        subject.call
      end
    end
  end

  def stub_email_delivery
    email_notifier = instance_double(EmailNotifier)
    allow(EmailNotifier).to receive(:new).with(user).and_return(email_notifier)
    allow(email_notifier).to receive(:send_password_changed_email)
  end
end
