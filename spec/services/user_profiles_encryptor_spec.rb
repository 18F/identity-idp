require 'rails_helper'

RSpec.describe UserProfilesEncryptor do
  describe '#call' do
    let(:user_session) { {}.with_indifferent_access }
    let(:pii) { Pii::Attributes.new(ssn: '1234') }
    let(:profile) { create(:profile, :active, :verified, pii: pii.to_h) }
    let(:user) { profile.user }
    let(:password) { 'a new and incredibly exciting password' }

    before do
      Pii::Cacher.new(user, user_session).save_decrypted_pii(pii, profile.id)
    end

    context 'when the user has an active profile' do
      it 'encrypts the PII for the active profile with the password' do
        encryptor = UserProfilesEncryptor.new(
          user: user,
          user_session: user_session,
          password: password,
        )
        encryptor.encrypt

        profile.reload

        personal_key = PersonalKeyGenerator.new(user).normalize(encryptor.personal_key)

        decrypted_profile_pii = profile.decrypt_pii(password)
        decrypted_profile_recovery_pii = profile.recover_pii(personal_key)

        expect(pii).to eq(decrypted_profile_pii)
        expect(pii).to eq(decrypted_profile_recovery_pii)
        expect(user.valid_personal_key?(personal_key)).to eq(true)
      end
    end

    context 'when the user has a pending profile' do
      let(:profile) { create(:profile, :verify_by_mail_pending, :verified, pii: pii.to_h) }
      let(:encryptor) do
        UserProfilesEncryptor.new(
          user: user,
          user_session: user_session,
          password: password,
        )
      end
      let(:personal_key) { PersonalKeyGenerator.new(user).normalize(encryptor.personal_key) }
      let(:decrypted_profile_pii) { profile.decrypt_pii(password) }
      let(:decrypted_profile_recovery_pii) { profile.recover_pii(personal_key) }

      it 'encrypts the PII for the pending profile with the password' do
        encryptor.encrypt
        profile.reload

        expect(decrypted_profile_pii).to eq(pii)
        expect(decrypted_profile_recovery_pii).to eq(pii)
        expect(user.valid_personal_key?(personal_key)).to eq(true)
      end

      context 'but the pending profile has no PII associated with it' do
        before { user_session.delete(:encrypted_profiles) }

        it 'deactivates the profile with an encryption error' do
          encryptor.encrypt
          profile.reload

          expect(profile.deactivation_reason).to eq('encryption_error')
        end
      end
    end

    context 'when the user has an active and a pending profile' do
      let(:active_pii) { pii }
      let(:active_profile) { profile }
      let(:pending_pii) { Pii::Attributes.new(ssn: '5555') }
      let(:pending_profile) do
        create(
          :profile,
          :verify_by_mail_pending,
          :verified,
          pii: pending_pii.to_h,
          user: user,
        )
      end

      before do
        Pii::Cacher.new(user, user_session).save_decrypted_pii(pending_pii, pending_profile.id)
      end

      it 'encrypts the PII for both profiles with the password' do
        encryptor = UserProfilesEncryptor.new(
          user: user,
          user_session: user_session,
          password: password,
        )
        encryptor.encrypt

        active_profile.reload
        pending_profile.reload

        decrypted_active_profile_pii = active_profile.decrypt_pii(password)
        decrypted_pending_profile_pii = pending_profile.decrypt_pii(password)

        expect(decrypted_active_profile_pii).to eq(active_pii)
        expect(decrypted_pending_profile_pii).to eq(pending_pii)
      end

      it 'sets the pending profile personal key as the personal key' do
        encryptor = UserProfilesEncryptor.new(
          user: user,
          user_session: user_session,
          password: password,
        )
        encryptor.encrypt

        active_profile.reload
        pending_profile.reload

        personal_key = PersonalKeyGenerator.new(user).normalize(encryptor.personal_key)

        expect do
          active_profile.recover_pii(personal_key)
        end.to raise_error(Encryption::EncryptionError)

        decrypted_pending_profile_recovery_pii = pending_profile.recover_pii(personal_key)
        expect(decrypted_pending_profile_recovery_pii).to eq(pending_pii)

        expect(user.valid_personal_key?(personal_key)).to eq(true)
      end
    end
  end
end
