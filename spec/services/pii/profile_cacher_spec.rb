require 'rails_helper'

RSpec.describe Pii::ProfileCacher do
  let(:password) { 'salty peanuts are best' }
  let(:user) { create(:user, :with_phone, password:) }
  let(:user_session) { {}.with_indifferent_access }

  let(:active_pii) do
    Pii::Attributes.new(
      first_name: 'Test',
      last_name: 'Testerson',
      dob: '2023-01-01',
      zipcode: '10000',
      ssn: '123-45-6789',
    )
  end
  let(:active_profile) do
    profile = create(:profile, :active, :verified, user:)
    profile.encrypt_pii(active_pii, password)
    profile
  end

  let(:pending_pii) do
    Pii::Attributes.new(
      first_name: 'Test2',
      last_name: 'Testerson2',
      dob: '2023-01-01',
      zipcode: '10000',
      ssn: '999-99-9999',
    )
  end
  let(:pending_profile) do
    profile = create(:profile, :verified, :verify_by_mail_pending, user:)
    profile.encrypt_pii(pending_pii, password)
    profile
  end

  subject { described_class.new(user, user_session) }

  describe '#save' do
    it 'writes decrypted PII to user_session for multiple profiles' do
      decrypted_active_pii = subject.save(password, active_profile)
      decrypted_pending_pii = subject.save(password, pending_profile)

      expect(decrypted_active_pii).to eq(active_pii)
      expect(decrypted_pending_pii).to eq(pending_pii)

      encrypted_active_session_pii = user_session[:encrypted_profiles][active_profile.id.to_s]
      decrypted_active_session_pii = SessionEncryptor.new.kms_decrypt(encrypted_active_session_pii)
      expect(decrypted_active_session_pii).to eq(active_pii.to_json)

      encrypted_pending_session_pii = user_session[:encrypted_profiles][pending_profile.id.to_s]
      decrypted_pending_session_pii = SessionEncryptor.new.kms_decrypt(
        encrypted_pending_session_pii,
      )
      expect(decrypted_pending_session_pii).to eq(pending_pii.to_json)
    end

    it 'updates PII bundle fingerprints when keys are rotated' do
      old_ssn_signature = active_profile.ssn_signature
      old_compound_pii_fingerprint = active_profile.name_zip_birth_year_signature

      rotate_all_keys

      # Create a new user object to drop the memoized encrypted attributes
      reloaded_user = User.find(user.id)

      described_class.new(reloaded_user, user_session).save(password, active_profile)

      active_profile.reload

      expect(active_profile.ssn_signature).to_not eq(old_ssn_signature)
      expect(active_profile.name_zip_birth_year_signature).to_not eq(old_compound_pii_fingerprint)
    end

    it 'does not attempt to rotate nil attributes' do
      cacher = described_class.new(user, user_session)
      rotate_all_keys

      expect { cacher.save(password, nil) }.to_not raise_error
    end

    it 'does not raise an error if pii fingerprint is nil but attributes are present' do
      # The name_zip_birth_year_signature column was added after users  had
      # ecrypted PII. As a result, those users may have a profile with valid PII
      # and a nil value here. Caching the PII into the session for those users
      # should update the signature column without raising an error
      active_profile.update!(name_zip_birth_year_signature: nil)

      subject.save(password, active_profile)

      expect(active_profile.reload.name_zip_birth_year_signature).to_not be_nil
    end

    it 'raises an encryption error for an incorrect password' do
      expect do
        subject.save('incorrect password', active_profile)
      end.to raise_error(Encryption::EncryptionError)
    end
  end

  describe '#fetch' do
    it 'fetches decrypted PII from user_session' do
      user_session[:encrypted_profiles] = {
        '123' => SessionEncryptor.new.kms_encrypt(active_pii.to_json),
        '456' => SessionEncryptor.new.kms_encrypt(pending_pii.to_json),
      }

      result = subject.fetch(123)

      expect(result).to eq(active_pii)
    end

    it 'returns nil if the encrypted profiles are not present' do
      result = subject.fetch(123)

      expect(result).to eq(nil)
    end

    it 'returns nil a profile has not been decrypted and loaded into the session' do
      user_session[:encrypted_profiles] = {
        '456' => SessionEncryptor.new.kms_encrypt(pending_pii.to_json),
      }

      result = subject.fetch(123)

      expect(result).to eq(nil)
    end
  end

  describe '#exists_in_session?' do
    it 'returns true if the encrypted profiles are in the session' do
      user_session[:encrypted_profiles] = {
        '123' => SessionEncryptor.new.kms_encrypt(active_pii.to_json),
        '456' => SessionEncryptor.new.kms_encrypt(pending_pii.to_json),
      }

      expect(subject.exists_in_session?).to eq(true)
    end

    it 'returns false if the encrypted profiles are in the session' do
      expect(subject.exists_in_session?).to eq(false)
    end
  end

  describe '#delete' do
    it 'deletes the encrypted profiles from the session' do
      user_session[:encrypted_profiles] = {
        '123' => SessionEncryptor.new.kms_encrypt(active_pii.to_json),
        '456' => SessionEncryptor.new.kms_encrypt(pending_pii.to_json),
      }

      subject.delete

      expect(user_session).to eq({})
    end
  end
end
