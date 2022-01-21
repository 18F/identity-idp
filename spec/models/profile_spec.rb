require 'rails_helper'

describe Profile do
  let(:user) { create(:user, :signed_up, password: 'a really long sekrit') }
  let(:another_user) { create(:user, :signed_up) }
  let(:profile) { create(:profile, user: user) }

  let(:dob) { '1920-01-01' }
  let(:ssn) { '666-66-1234' }
  let(:pii) do
    Pii::Attributes.new_from_hash(
      dob: dob,
      ssn: ssn,
      first_name: 'Jane',
      last_name: 'Doe',
      zipcode: '20001',
    )
  end

  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:gpo_confirmation_codes).dependent(:destroy) }

  describe '#proofing_components' do
    let(:profile) { create(:profile, proofing_components: proofing_components) }

    context 'when the value is nil' do
      let(:proofing_components) { nil }
      it 'is nil' do
        expect(profile.proofing_components).to eq(nil)
      end
    end

    context 'when the value is the empty string' do
      let(:proofing_components) { '' }
      it 'is the empty string' do
        expect(profile.proofing_components).to eq('')
      end

      it 'does not blow up in #includes_liveness_check?' do
        expect(profile.includes_liveness_check?).to be_falsey
      end
    end

    context 'when the value is a JSON object' do
      let(:proofing_components) { { 'foo' => true } }
      it 'is the object' do
        expect(profile.proofing_components).to eq('foo' => true)
      end
    end
  end

  describe '#encrypt_pii' do
    subject(:encrypt_pii) { profile.encrypt_pii(pii, user.password) }

    it 'encrypts PII' do
      expect(profile.encrypted_pii).to be_nil

      encrypt_pii

      expect(profile.encrypted_pii).to_not be_nil
      expect(profile.encrypted_pii).to_not match 'Jane'
      expect(profile.encrypted_pii).to_not match(ssn)
      expect(profile.encrypted_pii).to_not match(ssn.tr('-', ''))
    end

    it 'generates new personal key' do
      expect(profile.encrypted_pii_recovery).to be_nil

      initial_personal_key = user.encrypted_recovery_code_digest

      encrypt_pii

      expect(profile.encrypted_pii_recovery).to_not be_nil
      expect(user.reload.encrypted_recovery_code_digest).to_not eq initial_personal_key
    end

    it 'updates the personal key digest generation time' do
      user.encrypted_recovery_code_digest_generated_at = nil

      encrypt_pii

      expect(user.reload.encrypted_recovery_code_digest_generated_at.to_i).
        to be_within(1).of(Time.zone.now.to_i)
    end

    context 'ssn fingerprinting' do
      it 'fingerprints the ssn' do
        expect { encrypt_pii }.
          to change { profile.ssn_signature }.
          from(nil).to(Pii::Fingerprinter.fingerprint(ssn))
      end

      context 'ssn is blank' do
        let(:ssn) { nil }

        it 'does not fingerprint the SSN' do
          expect { encrypt_pii }.
            to_not change { profile.ssn_signature }.
            from(nil)
        end
      end
    end

    it 'fingerprints the PII' do
      fingerprint = Pii::Fingerprinter.fingerprint(
        [
          pii.first_name,
          pii.last_name,
          pii.zipcode,
          Date.parse(pii.dob).year,
        ].join(':'),
      )

      expect { encrypt_pii }.
        to change { profile.name_zip_birth_year_signature }.
        from(nil).to(fingerprint)
    end

    context 'when a part of the compound PII key is missing' do
      let(:dob) { nil }

      it 'does not write a fingerprint' do
        expect { encrypt_pii }.
          to_not change { profile.name_zip_birth_year_signature }.
          from(nil)
      end
    end
  end

  describe '#encrypt_recovery_pii' do
    it 'generates new personal key' do
      expect(profile.encrypted_pii_recovery).to be_nil

      initial_personal_key = user.encrypted_recovery_code_digest

      profile.encrypt_recovery_pii(pii)

      expect(profile.encrypted_pii_recovery).to_not be_nil
      expect(user.reload.encrypted_recovery_code_digest).to_not eq initial_personal_key
      expect(profile.personal_key).to_not eq user.encrypted_recovery_code_digest
    end
  end

  describe '#decrypt_pii' do
    it 'decrypts PII' do
      expect(profile.encrypted_pii).to be_nil

      profile.encrypt_pii(pii, user.password)

      decrypted_pii = profile.decrypt_pii(user.password)

      expect(decrypted_pii).to eq pii
    end

    it 'fails if the encryption context from the uuid is incorrect' do
      profile.encrypt_pii(pii, user.password)

      allow(profile.user).to receive(:uuid).and_return('a-different-uuid')

      expect { profile.decrypt_pii(user.password) }.to raise_error(Encryption::EncryptionError)
    end
  end

  describe '#recover_pii' do
    it 'decrypts the encrypted_pii_recovery using a personal key' do
      expect(profile.encrypted_pii_recovery).to be_nil

      profile.encrypt_pii(pii, user.password)
      personal_key = profile.personal_key

      normalized_personal_key = PersonalKeyGenerator.new(user).normalize(personal_key)

      expect(profile.recover_pii(normalized_personal_key)).to eq pii
    end
  end

  describe 'allows only one active Profile per user' do
    it 'prevents create! via ActiveRecord uniqueness validation' do
      profile.active = true
      profile.save!
      expect { Profile.create!(user_id: user.id, active: true) }.
        to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents save! via psql unique partial index' do
      profile.active = true
      profile.save!
      expect do
        another_profile = Profile.new(user_id: user.id, active: true)
        another_profile.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '#activate' do
    it 'activates current Profile, de-activates all other Profile for the user' do
      active_profile = Profile.create(user: user, active: true)
      profile.activate
      active_profile.reload
      expect(active_profile).to_not be_active
      expect(profile).to be_active
    end

    it 'sends a reproof completed push event' do
      Profile.create(user: user, active: true)
      expect(PushNotification::HttpPush).to receive(:deliver).
        with(PushNotification::ReproofCompletedEvent.new(user: user))

      profile.activate
    end

    it 'does not send a reproof event when there is a non active profile' do
      expect(PushNotification::HttpPush).to_not receive(:deliver)

      Profile.create(user: user, active: false)
      profile.activate
    end

    it 'does not send a reproof event when there is no active profile' do
      expect(PushNotification::HttpPush).to_not receive(:deliver)

      profile.activate
    end
  end

  describe '#deactivate' do
    it 'sets active flag to false' do
      profile = create(:profile, :active, user: user)
      profile.deactivate(:password_reset)

      expect(profile).to_not be_active
      expect(profile).to be_password_reset
    end
  end

  describe 'scopes' do
    describe '#active' do
      it 'returns only active Profiles' do
        user.profiles.create(active: false)
        user.profiles.create(active: true)
        expect(user.profiles.active.count).to eq 1
      end
    end

    describe '#verified' do
      it 'returns only verified Profiles' do
        user.profiles.create(verified_at: Time.zone.now)
        user.profiles.create(verified_at: nil)
        expect(user.profiles.verified.count).to eq 1
      end
    end
  end
end
