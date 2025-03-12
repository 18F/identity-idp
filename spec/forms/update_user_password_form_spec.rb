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
    UpdateUserPasswordForm.new(user: user, user_session: user_session)
  end

  it_behaves_like 'password validation'
  it_behaves_like 'strong password', 'UpdateUserPasswordForm'

  describe '#submit' do
    context 'when the password is invalid' do
      let(:password) { 'invalid' }

      it 'returns FormResponse with success: false and does not do anything else' do
        expect(UserProfilesEncryptor).not_to receive(:new)
        user.save!

        old_digest = user.encrypted_password_digest
        old_digest_multi_region = user.encrypted_password_digest_multi_region

        result = subject.submit(params).to_h
        expect(old_digest_multi_region).to eq(user.reload.encrypted_password_digest_multi_region)
        expect(old_digest).to eq(user.reload.encrypted_password_digest)

        expect(result).to include(
          success: false,
          error_details: hash_including(:password, :password_confirmation),
        )
      end
    end

    context 'when the password is valid' do
      it 'returns FormResponse with success: true' do
        expect(subject.submit(params).to_h).to eq(
          success: true,
          active_profile_present: false,
          pending_profile_present: false,
          user_id: user.uuid,
          required_password_change: false,
        )
      end

      it 'updates the user password' do
        user.save!

        expect do
          subject.submit(params)
        end.to(
          change { user.reload.encrypted_password_digest_multi_region }.and(
            change { user.reload.encrypted_password_digest },
          ),
        )
      end
    end

    context 'when the user has an active profile' do
      let(:profile) { create(:profile, :active, :verified, pii: { ssn: '1234' }) }
      let(:user) { profile.user }
      let(:user_session) { {} }

      before do
        Pii::Cacher.new(user, user_session).save_decrypted_pii({ ssn: '1234' }, profile.id)
      end

      it 'encrypts the active profile' do
        encryptor = instance_double(UserProfilesEncryptor)
        allow(UserProfilesEncryptor).to receive(:new)
          .with(user: user, user_session: user_session, password: password).and_return(encryptor)
        allow(encryptor).to receive(:encrypt)

        subject.submit(params)

        expect(encryptor).to have_received(:encrypt)
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
      let(:user_session) { {} }

      before do
        Pii::Cacher.new(user, user_session).save_decrypted_pii({ ssn: '1234' }, profile.id)
      end

      it 'encrypts the pending profile' do
        encryptor = instance_double(UserProfilesEncryptor)
        allow(UserProfilesEncryptor).to receive(:new)
          .with(user: user, user_session: user_session, password: password).and_return(encryptor)
        allow(encryptor).to receive(:encrypt)

        subject.submit(params)

        expect(encryptor).to have_received(:encrypt)
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
      it 'does not call UserProfilesEncryptor' do
        expect(UserProfilesEncryptor).to_not receive(:new)

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
