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
        result = instance_double(FormResponse)

        expect(FormResponse).to receive(:new).
          with(success: true, errors: {}).and_return(result)
        expect(subject.submit(params)).to eq result
      end

      it 'updates the user' do
        user_updater = instance_double(UpdateUser)
        allow(UpdateUser).to receive(:new).
          with(user: user, attributes: { password: 'salty new password' }).
          and_return(user_updater)
        allow(user_updater).to receive(:call)

        subject.submit(params)

        expect(user_updater).to have_received(:call)
      end
    end

    context 'when the user has an active profile' do
      let(:profile) { create(:profile, :active, :verified, pii: { ssn: '1234' }) }
      let(:user) { profile.user }

      it 'encrypts the active profile' do
        allow(user).to receive(:active_profile).and_return(profile)

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
        expect(ActiveProfileEncryptor).to_not receive(:new)

        subject.submit(params)
      end
    end
  end
end
