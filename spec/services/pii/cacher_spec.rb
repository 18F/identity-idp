require 'rails_helper'

describe Pii::Cacher do
  let(:password) { 'salty peanuts are best' }
  let(:user) { create(:user, :with_phone, password: password, otp_secret_key: 'abc123') }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }
  let(:diff_profile) { build(:profile, :verified, user: user, pii: { ssn: '5678' }) }
  let(:user_session) { {} }

  subject { described_class.new(user, user_session) }

  describe '#save' do
    before do
      allow(FeatureManagement).to receive(:use_kms?).and_return(false)
      profile.save!
    end

    it 'writes decrypted PII to user_session' do
      decrypted_pii_json = subject.save(password)
      decrypted_pii = JSON.parse(decrypted_pii_json, symbolize_names: true)

      expect(decrypted_pii[:ssn]).to eq '1234'
      expect(user_session[:decrypted_pii]).to eq decrypted_pii_json
    end

    it 'allows specific profile to be decrypted' do
      diff_profile.save!
      decrypted_pii_json = subject.save(password, diff_profile)
      decrypted_pii = JSON.parse(decrypted_pii_json, symbolize_names: true)

      expect(decrypted_pii[:ssn]).to_not eq '1234'
      expect(decrypted_pii[:ssn]).to eq '5678'
      expect(user_session[:decrypted_pii]).to eq decrypted_pii_json
    end

    it 'updates fingerprints when keys are rotated' do
      old_ssn_signature = profile.ssn_signature
      old_email_fingerprint = user.email_fingerprint
      old_encrypted_email = user.encrypted_email
      old_encrypted_phone = user.encrypted_phone
      old_encrypted_otp_secret_key = user.encrypted_otp_secret_key

      rotate_all_keys

      # Create a new user object to drop the memoized encrypted attributes
      user_id = user.id
      reloaded_user = User.find(user_id)
      reloaded_profile = user.profiles.first

      described_class.new(reloaded_user, user_session).save(password)

      user.reload
      profile.reload

      expect(user.email_fingerprint).to_not eq old_email_fingerprint
      expect(user.encrypted_email).to_not eq old_encrypted_email
      expect(profile.ssn_signature).to_not eq old_ssn_signature
      expect(user.encrypted_phone).to_not eq old_encrypted_phone
      expect(user.encrypted_otp_secret_key).to_not eq old_encrypted_otp_secret_key
    end

    it 'does not attempt to rotate nil attributes' do
      user = create(:user, password: password)
      cacher = described_class.new(user, user_session)
      rotate_all_keys

      expect { cacher.save(password) }.to_not raise_error
    end
  end

  describe '#fetch' do
    before do
      allow(FeatureManagement).to receive(:use_kms?).and_return(false)
      profile.save!
    end

    it 'fetches decrypted PII from user_session' do
      subject.save(password)
      decrypted_pii = subject.fetch

      expect(decrypted_pii).to be_a Pii::Attributes
      expect(decrypted_pii.ssn).to eq '1234'
    end

    it 'allows specific profile to be decrypted' do
      diff_profile.save!
      subject.save(password, diff_profile)
      decrypted_pii = subject.fetch

      expect(decrypted_pii).to be_a Pii::Attributes
      expect(decrypted_pii.ssn).to_not eq '1234'
      expect(decrypted_pii.ssn).to eq '5678'
    end
  end
end
