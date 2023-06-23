require 'rails_helper'

RSpec.describe Pii::Cacher do
  let(:password) { 'salty peanuts are best' }
  let(:user) { create(:user, :with_phone, password: password) }
  let(:profile) do
    build(
      :profile, :active, :verified,
      user: user,
      pii: {
        ssn: '1234',
        dob: '1970-01-01',
        first_name: 'Test',
        last_name: 'McTesterson',
        zipcode: '20001',
      }
    )
  end
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

    it 'updates PII bundle fingerprints when keys are rotated' do
      old_ssn_signature = profile.ssn_signature
      old_compound_pii_fingerprint = profile.name_zip_birth_year_signature

      rotate_all_keys

      # Create a new user object to drop the memoized encrypted attributes
      user_id = user.id
      reloaded_user = User.find(user_id)

      described_class.new(reloaded_user, user_session).save(password)

      user.reload
      profile.reload

      expect(profile.ssn_signature).to_not eq old_ssn_signature
      expect(profile.name_zip_birth_year_signature).to_not eq old_compound_pii_fingerprint
    end

    it 'does not attempt to rotate nil attributes' do
      user = create(:user, password: password)
      cacher = described_class.new(user, user_session)
      rotate_all_keys

      expect { cacher.save(password) }.to_not raise_error
    end

    it 'does not raise an error if pii_fingerprint is nil but attributes are present' do
      # The name_zip_birth_year_signature column was added after users  had
      # ecrypted PII. As a result, those users may have a profile with valid PII
      # and a nil value here. Caching the PII into the session for those users
      # should update the signature column without raising an error
      profile.update!(name_zip_birth_year_signature: nil)

      subject.save(password, profile)

      expect(profile.reload.name_zip_birth_year_signature).to_not be_nil
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
