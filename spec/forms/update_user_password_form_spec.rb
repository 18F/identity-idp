require 'rails_helper'

describe UpdateUserPasswordForm, type: :model do
  let(:user) { build(:user, password: 'old strong password') }
  let(:user_session) { {} }
  let(:password) { 'salty new password' }
  let(:params) { { password: password } }
  let(:subject) do
    UpdateUserPasswordForm.new(user, user_session)
  end

  it_behaves_like 'password validation'
  it_behaves_like 'strong password', 'UpdateUserPasswordForm'

  describe '#submit' do
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
        expect(subject.submit(params)).to eq result
      end
    end

    context 'when the password is valid' do
      it 'returns FormResponse with success: true' do
        stub_email_delivery

        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}).and_return(result)
        expect(subject.submit(params)).to eq result
      end

      it 'updates the user' do
        stub_email_delivery

        user_updater = instance_double(UpdateUser)
        allow(UpdateUser).to receive(:new).
          with(user: user, attributes: { password: 'salty new password' }).
          and_return(user_updater)
        allow(user_updater).to receive(:call)

        subject.submit(params)

        expect(user_updater).to have_received(:call)
      end

      it 'sends an email to notify of the password change' do
        mailer = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
        allow(UserMailer).to receive(:password_changed).with(user).and_return(mailer)

        subject.submit(params)

        expect(mailer).to have_received(:deliver_later)
      end

      it 'increments password metrics for the password' do
        params[:password] = 'saltypickles'
        stub_email_delivery

        subject.submit(params)

        expect(PasswordMetric.where(metric: 'length', value: 12, count: 1).count).to eq(1)
        expect(PasswordMetric.where(metric: 'guesses_log10', value: 7.1, count: 1).count).to eq(1)
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

        subject.submit(params)

        expect(encryptor).to have_received(:call)
      end
    end

    context 'when the user does not have an active profile' do
      it 'does not call ActiveProfileEncryptor' do
        mailer = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
        expect(UserMailer).to receive(:password_changed).with(user).and_return(mailer)
        expect(ActiveProfileEncryptor).to_not receive(:new)

        subject.submit(params)
      end
    end
  end

  def stub_email_delivery
    mailer = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    allow(UserMailer).to receive(:password_changed).with(user).and_return(mailer)
  end
end
