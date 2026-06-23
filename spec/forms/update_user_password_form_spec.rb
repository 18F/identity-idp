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

        old_digest = user.encrypted_password_digest_multi_region

        result = subject.submit(params).to_h
        expect(old_digest).to eq(user.reload.encrypted_password_digest_multi_region)

        expect(result).to include(
          success: false,
          error_details: hash_including(:password, :password_confirmation),
        )
      end

      it 'does not attempt to reencrypt the attempt events' do
        expect(AttemptsApi::Cacher).not_to receive(:new)
        subject.submit(params)
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
        end.to(change { user.reload.encrypted_password_digest_multi_region })
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

      context 'there are no existing attempt events cached in the session' do
        it 'does not attempt to reencrypt the attempt events' do
          expect(AttemptsApi::Cacher).to receive(:new).with(user, user_session).and_call_original
          expect_any_instance_of(Profile).not_to receive(:reencrypt_user_proofing_events)

          subject.submit(params)
        end
      end

      context 'there are existing attempt events cached in the session' do
        let(:decrypted_events) do
          [
            { event_type: 'idv-event', jti: 'some-jti' },
            { event_type: 'idv-another-event', jti: 'another-jti' },
          ]
        end

        let(:user_session) do
          {
            encrypted_proofing_events: SessionEncryptor.new.kms_encrypt(decrypted_events.to_json),
          }
        end

        let(:personal_key) { 'personal-key' }
        before do
          allow_any_instance_of(Profile).to receive(:encrypt_pii).and_return(personal_key)
          allow_any_instance_of(Profile).to receive(:reencrypt_user_proofing_events)
        end

        it 'attempts to reencrypt the attempt events with the new password' do
          expect(AttemptsApi::Cacher).to receive(:new).with(user, user_session).and_call_original
          expect_any_instance_of(Profile).to receive(:reencrypt_user_proofing_events).with(
            password:,
            attempt_events: decrypted_events.as_json,
            personal_key:,
          )

          subject.submit(params)
        end
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

      it 'does not attempt to reencrypt the attempt events' do
        expect(AttemptsApi::Cacher).not_to receive(:new)
        subject.submit(params)
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

      it 'does not attempt to reencrypt the attempt events' do
        expect(AttemptsApi::Cacher).not_to receive(:new)
        subject.submit(params)
      end
    end
  end
end
