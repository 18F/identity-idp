require 'rails_helper'

RSpec.describe UpdateUserPasswordForm, type: :model do
  let(:user) { build(:user, password: 'old strong password') }
  let(:user_session) { {} }
  let(:password) { 'salty new password' }
  let(:params) do
    {
      password: password,
      password_confirmation: password,
    }
  end
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
          password: [t(
            'errors.attributes.password.too_short.other',
            count: Devise.password_length.first,
          )],
          password_confirmation: [I18n.t(
            'errors.messages.too_short',
            count: Devise.password_length.first,
          )],
        }

        expect(UpdateUser).not_to receive(:new)
        expect(ActiveProfileEncryptor).not_to receive(:new)
        expect(subject.submit(params).to_h).to include(
          success: false,
          errors: errors,
          error_details: hash_including(:password, :password_confirmation),
        )
      end
    end

    context 'when the password is valid' do
      it 'returns FormResponse with success: true' do
        expect(subject.submit(params).to_h).to eq(
          success: true,
          errors: {},
          active_profile_present: false,
          pending_profile_present: false,
          user_id: user.uuid,
        )
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
      let(:user_session) { { decrypted_pii: { ssn: '1234' }.to_json } }

      it 'encrypts the active profile' do
        encryptor = instance_double(ActiveProfileEncryptor)
        allow(ActiveProfileEncryptor).to receive(:new).
          with(user, user_session, password).and_return(encryptor)
        allow(encryptor).to receive(:call)

        subject.submit(params)

        expect(encryptor).to have_received(:call)
      end

      it 'logs that the user has an active profile' do
        result = subject.submit(params)

        expect(result.extra).to include(
          active_profile_present: true,
          pending_profile_present: false,
        )
      end
    end

    context 'the user has a pending profile' do
      let(:profile) { create(:profile, :verify_by_mail_pending, :verified, pii: { ssn: '1234' }) }
      let(:user) { profile.user }

      it 'does not call ActiveProfileEncryptor' do
        expect(ActiveProfileEncryptor).to_not receive(:new)

        subject.submit(params)
      end

      it 'logs that the user has a pending profile' do
        result = subject.submit(params)

        expect(result.extra).to include(
          active_profile_present: false,
          pending_profile_present: true,
        )
      end
    end

    context 'when the user does not have a profile' do
      it 'does not call ActiveProfileEncryptor' do
        expect(ActiveProfileEncryptor).to_not receive(:new)

        subject.submit(params)
      end

      it 'logs that the user does not have an active or pending profile' do
        result = subject.submit(params)

        expect(result.extra).to include(
          active_profile_present: false,
          pending_profile_present: false,
        )
      end
    end
  end
end
