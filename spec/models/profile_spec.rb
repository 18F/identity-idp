require 'rails_helper'

RSpec.describe Profile do
  let(:user) { create(:user, :fully_registered, password: 'a really long sekrit') }
  let(:another_user) { create(:user, :fully_registered) }
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
  it { is_expected.to have_one(:in_person_enrollment).dependent(:destroy) }

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
    end

    context 'when the value is a JSON object' do
      let(:proofing_components) { { 'foo' => true } }
      it 'is the object' do
        expect(profile.proofing_components).to eq('foo' => true)
      end
    end
  end

  describe '#includes_phone_check?' do
    it 'returns true if the address_check component is lexis_nexis_address' do
      profile = create(:profile, proofing_components: { address_check: 'lexis_nexis_address' })

      expect(profile.includes_phone_check?).to eq(true)
    end

    it 'returns false if the address_check componet is gpo_letter' do
      profile = create(:profile, proofing_components: { address_check: 'gpo_letter' })

      expect(profile.includes_phone_check?).to eq(false)
    end

    it 'returns false if proofing_components is blank' do
      profile = create(:profile, proofing_components: '')

      expect(profile.includes_phone_check?).to eq(false)
    end
  end

  describe '#in_person_verification_pending?' do
    it 'returns true if the deactivation_reason is in_person_verification_pending' do
      profile = create(
        :profile,
        :in_person_verification_pending,
        user: user,
      )

      allow(profile).to receive(:update!).and_raise(RuntimeError)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('in_person_verification_pending')
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil
    end
  end

  describe '#encrypt_pii' do
    subject(:encrypt_pii) { profile.encrypt_pii(pii, user.password) }

    it 'encrypts pii and stores the multi region ciphertext' do
      expect(profile.encrypted_pii).to be_nil
      expect(profile.encrypted_pii_recovery).to be_nil
      expect(profile.encrypted_pii_multi_region).to be_nil
      expect(profile.encrypted_pii_recovery_multi_region).to be_nil

      profile.encrypt_pii(pii, user.password)

      expect(profile.encrypted_pii).to be_present
      expect(profile.encrypted_pii).to_not match 'Jane'
      expect(profile.encrypted_pii).to_not match(ssn)

      expect(profile.encrypted_pii_recovery).to be_present
      expect(profile.encrypted_pii_recovery).to_not match 'Jane'
      expect(profile.encrypted_pii_recovery).to_not match(ssn)

      expect(profile.encrypted_pii_multi_region).to be_present
      expect(profile.encrypted_pii_multi_region).to_not match 'Jane'
      expect(profile.encrypted_pii_multi_region).to_not match(ssn)

      expect(profile.encrypted_pii_recovery_multi_region).to be_present
      expect(profile.encrypted_pii_recovery_multi_region).to_not match 'Jane'
      expect(profile.encrypted_pii_recovery_multi_region).to_not match(ssn)
    end

    it 'generates new personal key' do
      expect(profile.encrypted_pii_recovery).to be_nil

      initial_personal_key = user.encrypted_recovery_code_digest

      encrypt_pii

      expect(profile.encrypted_pii_recovery).to be_present
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

      expect(profile.encrypted_pii_recovery).to be_present
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

    context 'with aws_kms_multi_region_read_enabled enabled' do
      before do
        allow(IdentityConfig.store).to receive(:aws_kms_multi_region_read_enabled).and_return(true)
      end

      it 'decrypts the PII for users with a multi region ciphertext' do
        profile.encrypt_pii(pii, user.password)

        expect(profile.encrypted_pii_multi_region).to_not be_nil

        decrypted_pii = profile.decrypt_pii(user.password)

        expect(decrypted_pii).to eq pii
      end

      it 'decrypts the PII for users with only a single region ciphertext' do
        profile.encrypt_pii(pii, user.password)
        profile.update!(encrypted_pii_multi_region: nil)

        decrypted_pii = profile.decrypt_pii(user.password)

        expect(decrypted_pii).to eq pii
      end
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

    context 'with aws_kms_multi_region_read_enabled enabled' do
      before do
        allow(IdentityConfig.store).to receive(:aws_kms_multi_region_read_enabled).and_return(true)
      end

      it 'decrypts the PII for users with a multi region ciphertext' do
        profile.encrypt_pii(pii, user.password)
        personal_key = profile.personal_key

        normalized_personal_key = PersonalKeyGenerator.new(user).normalize(personal_key)

        expect(profile.encrypted_pii_recovery_multi_region).to_not be_nil

        decrypted_pii = profile.recover_pii(normalized_personal_key)

        expect(decrypted_pii).to eq pii
      end

      it 'decrypts the PII for users with only a single region ciphertext' do
        profile.encrypt_pii(pii, user.password)
        profile.update!(encrypted_pii_recovery_multi_region: nil)
        personal_key = profile.personal_key

        normalized_personal_key = PersonalKeyGenerator.new(user).normalize(personal_key)

        decrypted_pii = profile.recover_pii(normalized_personal_key)

        expect(decrypted_pii).to eq pii
      end
    end
  end

  describe 'allows only one active Profile per user' do
    it 'prevents create! via ActiveRecord uniqueness validation' do
      expect(profile.activated_at).to be_nil # to change
      expect(profile.active).to eq(false) # to change
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil # to change

      profile.activate

      expect(profile.activated_at).to be_present # changed
      expect(profile.active).to eq(true) # changed
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present # changed

      # TODO: call activate on the new profile instead
      expect { user.profiles.create!(active: true) }.
        to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'prevents save! via psql unique partial index' do
      expect(profile.activated_at).to be_nil # to change
      expect(profile.active).to eq(false) # to change
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil # to change

      profile.activate

      expect(profile.activated_at).to be_present # changed
      expect(profile.active).to eq(true) # changed
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present # changed

      expect do
        another_profile = user.profiles.new(active: true)
        another_profile.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe '#activate' do
    it 'activates current Profile, de-activates all other Profile for the user' do
      active_profile = create(:profile, :active, user: user)

      # profile before
      expect(profile.activated_at).to be_nil # to change
      expect(profile.active).to eq(false) # to change
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil # to change

      # active_profile before
      expect(active_profile.activated_at).to be_present
      expect(active_profile.active).to eq(true) # to change
      expect(active_profile.deactivation_reason).to be_nil
      expect(active_profile.fraud_review_pending?).to eq(false)
      expect(active_profile.gpo_verification_pending_at).to be_nil
      expect(active_profile.in_person_verification_pending_at).to be_nil
      expect(active_profile.initiating_service_provider).to be_nil
      expect(active_profile.verified_at).to be_present

      profile.activate
      active_profile.reload

      # profile after
      expect(profile.activated_at).to be_present # changed
      expect(profile.active).to eq(true) # changed
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present # changed

      # active_profile after
      expect(active_profile.activated_at).to be_present
      expect(active_profile.active).to eq(false) # changed
      expect(active_profile.deactivation_reason).to be_nil
      expect(active_profile.fraud_review_pending?).to eq(false)
      expect(active_profile.gpo_verification_pending_at).to be_nil
      expect(active_profile.in_person_verification_pending_at).to be_nil
      expect(active_profile.initiating_service_provider).to be_nil

      # !!! a user can have multiple verified profiles
      expect(active_profile.verified_at).to be_present
    end

    it 'sends a reproof completed push event' do
      profile = create(:profile, :active, user: user)
      expect(PushNotification::HttpPush).to receive(:deliver).
        with(PushNotification::ReproofCompletedEvent.new(user: user))

      expect(profile.activated_at).to be_present
      expect(profile.active).to eq(true)
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present

      profile.activate

      expect(profile.activated_at).to be_present # changed
      expect(profile.active).to eq(true)
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present # changed
    end

    # this spec will pass for a deactivated profile which is non-active,
    # but will fail for password_reset and encryption_error profiles,
    # which are non-active, but are not activate-able
    it 'does not send a reproof event when there is a non active profile' do
      expect(PushNotification::HttpPush).to_not receive(:deliver)

      profile = create(:profile, :deactivated)

      expect(profile.activated_at).to be_present
      expect(profile.active).to eq(false) # to change
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil # to change

      profile.activate

      expect(profile.activated_at).to be_present
      expect(profile.active).to eq(true) # changed
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present # changed
    end

    it 'does not send a reproof event when there is no active profile' do
      expect(PushNotification::HttpPush).to_not receive(:deliver)

      expect(profile.activated_at).to be_nil # to change
      expect(profile.active).to eq(false) # to change
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil # to change

      profile.activate

      expect(profile.activated_at).to be_present # changed
      expect(profile.active).to eq(true) # changed
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present # changed
    end

    context 'activation guards against deactivation reasons' do
      before do
        allow(FeatureManagement).to receive(
          :proofing_device_profiling_decisioning_enabled?,
        ).and_return(true)
      end

      it 'does not activate a profile with gpo verification pending' do
        profile = create(:profile, :verify_by_mail_pending)

        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to be_nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at).to be_present
        expect(profile.in_person_verification_pending_at).to be_nil
        expect(profile.initiating_service_provider).to be_nil
        expect(profile.verified_at).to be_nil

        expect { profile.activate }.to raise_error(
          RuntimeError,
          'Attempting to activate profile with pending reasons: gpo_verification_pending',
        )

        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to be_nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at).to be_present
        expect(profile.in_person_verification_pending_at).to be_nil
        expect(profile.initiating_service_provider).to be_nil
        expect(profile.verified_at).to be_nil

        expect(profile).to_not be_active
      end

      it 'does not activate a profile if under fraud review' do
        profile = create(:profile, :fraud_review_pending)

        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to be_nil
        expect(profile.fraud_review_pending?).to eq(true)
        expect(profile.gpo_verification_pending_at).to be_nil
        expect(profile.in_person_verification_pending_at).to be_nil
        expect(profile.initiating_service_provider).to be_nil
        expect(profile.verified_at).to be_nil

        expect { profile.activate }.to raise_error(
          RuntimeError,
          'Attempting to activate profile with pending reasons: fraud_check_pending',
        )

        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to be_nil
        expect(profile.fraud_review_pending?).to eq(true)
        expect(profile.gpo_verification_pending_at).to be_nil
        expect(profile.in_person_verification_pending_at).to be_nil
        expect(profile.initiating_service_provider).to be_nil
        expect(profile.verified_at).to be_nil

        expect(profile).to_not be_active
      end

      it 'does not activate a profile if rejected for fraud' do
        profile = create(:profile, :fraud_rejection)

        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to be_nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at).to be_nil
        expect(profile.in_person_verification_pending_at).to be_nil
        expect(profile.initiating_service_provider).to be_nil
        expect(profile.verified_at).to be_nil

        expect { profile.activate }.to raise_error(
          RuntimeError,
          'Attempting to activate profile with pending reasons: fraud_check_pending',
        )

        expect(profile.activated_at).to be_nil
        expect(profile.active).to eq(false)
        expect(profile.deactivation_reason).to be_nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at).to be_nil
        expect(profile.in_person_verification_pending_at).to be_nil
        expect(profile.initiating_service_provider).to be_nil
        expect(profile.verified_at).to be_nil

        expect(profile).to_not be_active
      end
    end

    context 'When a profile already has a verified_at timestamp' do
      it 'does not update the timestamp when #activate is called' do
        profile = create(:profile, :verified, user: user)
        original_timestamp = profile.verified_at
        expect(profile.reason_not_to_activate).to be_nil
        profile.activate
        expect(profile.verified_at).to eq(original_timestamp)
      end
    end
  end

  describe '#deactivate' do
    let(:deactivation_reason) { :password_reset }

    it 'sets active flag to false and assigns deactivation_reason' do
      profile = create(:profile, :active, user: user)

      expect(profile.activated_at).to be_present
      expect(profile.active).to eq(true) # to change
      expect(profile.deactivation_reason).to be_nil # to change
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present

      profile.deactivate(deactivation_reason)

      expect(profile.activated_at).to be_present
      expect(profile.active).to eq(false) # changed
      expect(profile.deactivation_reason).to eq('password_reset') # changed
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil

      # !!! does a deactivated verified profile remain verified?
      expect(profile.verified_at).to be_present

      expect(profile).to_not be_active
      expect(profile).to be_password_reset
    end
  end

  describe '#remove_gpo_deactivation_reason' do
    it 'removes the gpo_verification_pending_at deactivation reason' do
      profile = create(:profile, :verify_by_mail_pending)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_present # to change
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      profile.remove_gpo_deactivation_reason

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil # changed
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      expect(profile.gpo_verification_pending?).to be(false)
    end
  end

  describe '#activate_after_password_reset' do
    it 'activates a non-verified, non-active, non-activated profile after password reset' do
      # TODO: this profile scenario shouldn't be possible
      profile = create(
        :profile,
        :password_reset,
        user: user,
      )

      # profile.initiating_service_provider is nil before and after because
      # the user is coming from a password reset email

      expect(profile.activated_at).to be_nil # will change but shouldn't
      expect(profile.active).to eq(false) # will change but shouldn't
      expect(profile.deactivation_reason).to eq 'password_reset' # will change but shouldn't
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      # TODO: this should raise an error
      profile.activate_after_password_reset

      expect(profile.activated_at).to be_present # !!! changed
      expect(profile.active).to eq(true) # !!! changed
      expect(profile.deactivation_reason).to be_nil # !!! changed
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil
    end

    it 'activates a previously verified profile after password reset' do
      profile = create(
        :profile,
        :active,
        :password_reset,
        user: user,
      )
      verified_at = profile.verified_at

      expect(profile.activated_at).to be_present
      expect(profile.active).to eq(false) # to change
      expect(profile.deactivation_reason).to eq 'password_reset' # to change
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to eq verified_at

      profile.activate_after_password_reset

      expect(profile.activated_at).to be_present
      expect(profile.active).to eq(true) # changed
      expect(profile.deactivation_reason).to be_nil # changed
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to eq verified_at
    end

    # ??? This method still nils out deactivation_reason even though it raises
    it 'does not activate a profile if it has a pending reason' do
      profile = create(
        :profile,
        :password_reset,
        :fraud_review_pending,
        user: user,
      )

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('password_reset') # to change
      expect(profile.fraud_review_pending?).to eq(true)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      expect { profile.activate_after_password_reset }.to raise_error(
        RuntimeError,
        'Attempting to activate profile with pending reasons: fraud_check_pending',
      )

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil # changed
      expect(profile.fraud_review_pending?).to eq(true)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      expect(profile).to_not be_active
    end

    it 'does not activate a profile with non password_reset deactivation_reason' do
      profile = create(
        :profile,
        :encryption_error,
        user: user,
      )

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq 'encryption_error'
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      profile.activate_after_password_reset

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq 'encryption_error'
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil
    end

    it 'does not activate a non-verified profile if it encounters a transaction error' do
      profile = create(
        :profile,
        :password_reset,
        user: user,
      )

      allow(profile).to receive(:update!).and_raise(RuntimeError)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('password_reset')
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      suppress(RuntimeError) do
        profile.activate_after_password_reset
      end

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('password_reset')
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      expect(profile.deactivation_reason).to eq('password_reset')
      expect(profile).to_not be_active
    end
  end

  describe '#activate_after_passing_in_person' do
    it 'activates a profile if it passes in person proofing' do
      profile = create(
        :profile,
        :fraud_review_pending,
        :in_person_verification_pending,
        user: user,
      )

      expect(profile.activated_at).to be_nil # to change
      expect(profile.active).to eq(false) # to change
      expect(profile.deactivation_reason).to eq 'in_person_verification_pending' # to change
      expect(profile.fraud_review_pending?).to eq(true) # to change
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_present
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil # to change

      profile.activate_after_passing_in_person

      expect(profile.activated_at).to be_present # changed
      expect(profile.active).to eq(true) # changed
      expect(profile.deactivation_reason).to be_nil # changed
      expect(profile.fraud_review_pending?).to eq(false) # changed
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present # changed

      expect(profile.fraud_review_pending_at).to be_nil
      expect(profile.activated_at).not_to be_nil
      expect(profile.deactivation_reason).to be_nil
      expect(profile).to be_active # changed
    end

    it 'does not activate a profile if transaction raises an error' do
      profile = create(
        :profile,
        :in_person_verification_pending,
        :fraud_review_pending,
        user: user,
      )

      allow(profile).to receive(:update!).and_raise(RuntimeError)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('in_person_verification_pending')
      expect(profile.fraud_review_pending?).to eq(true)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_present
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      suppress(RuntimeError) do
        profile.activate_after_passing_in_person
      end

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('in_person_verification_pending')
      expect(profile.fraud_review_pending?).to eq(true)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_present
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      expect(profile.deactivation_reason).to eq('in_person_verification_pending')
      expect(profile).to_not be_active
    end
  end

  describe '#activate_after_passing_review' do
    it 'activates a profile if it passes fraud review' do
      profile = create(:profile, :fraud_review_pending, user: user)

      expect(profile.activated_at).to be_nil # to change
      expect(profile.active).to eq(false) # to change
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(true) # to change
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil # to change

      profile.activate_after_passing_review

      expect(profile.activated_at).to be_present # changed
      expect(profile.active).to eq(true) # changed
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false) # changed
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present # changed

      expect(profile).to be_active
      expect(profile.fraud_review_pending_at).to be_nil
      expect(profile.fraud_pending_reason).to be_nil
    end

    it 'does not activate a profile if transaction raises an error' do
      profile = create(
        :profile,
        user: user,
        active: false,
        fraud_review_pending_at: 1.day.ago,
      )

      allow(profile).to receive(:update!).and_raise(RuntimeError)

      suppress(RuntimeError) do
        profile.activate_after_passing_review
      end

      expect(profile.fraud_review_pending_at).to_not eq nil
      expect(profile).to_not be_active
    end

    context 'when the initiating_sp is the IRS' do
      let(:sp) { create(:service_provider, :irs) }
      let(:profile) do
        create(
          :profile,
          user: user,
          active: false,
          fraud_review_pending_at: 1.day.ago,
          initiating_service_provider: sp,
        )
      end

      context 'when the feature flag is enabled' do
        before do
          allow(IdentityConfig.store).to receive(:irs_attempt_api_track_idv_fraud_review).
            and_return(true)
        end

        it 'logs an attempt event' do
          expect(profile.initiating_service_provider.irs_attempts_api_enabled?).to be_truthy

          expect(profile.irs_attempts_api_tracker).to receive(:fraud_review_adjudicated).
            with(
              hash_including(decision: 'pass'),
            )
          profile.activate_after_passing_review
        end
      end
    end
  end

  describe '#activate_after_fraud_review_unnecessary' do
    it 'activates a profile if fraud review is unnecessary' do
      profile = create(:profile, :fraud_review_pending, user: user)

      expect(profile.activated_at).to be_nil # to change
      expect(profile.active).to eq(false) # to change
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(true) # to change
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil # to change

      expect(profile).to_not be_active
      expect(profile.fraud_review_pending_at).to be_present
      expect(profile.fraud_pending_reason).to be_present

      profile.activate_after_fraud_review_unnecessary

      expect(profile.activated_at).to be_present # changed
      expect(profile.active).to eq(true) # changed
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false) # changed
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_present # changed

      expect(profile).to be_active
      expect(profile.fraud_review_pending_at).to be_nil
      expect(profile.fraud_pending_reason).to be_nil
    end

    it 'does not activate a profile if transaction raises an error' do
      profile = create(:profile, :fraud_review_pending, user: user)

      allow(profile).to receive(:update!).and_raise(RuntimeError)

      suppress(RuntimeError) do
        profile.activate_after_fraud_review_unnecessary
      end

      expect(profile.fraud_review_pending_at).to_not eq nil
      expect(profile).to_not be_active
    end
  end

  # TODO: does deactivating make sense for a non-active profile? Should we prevent it?
  # TODO: related: should we test against an active profile here?
  describe '#deactivate_for_in_person_verification' do
    it 'deactivates a profile for in_person_verification' do
      profile = create(:profile, user: user)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil # to change
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      profile.deactivate_for_in_person_verification

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('in_person_verification_pending') # changed
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_present # changed
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil
    end
  end

  # TODO: does deactivating make sense for a non-active profile? Should we prevent it?
  # TODO: related: should we test against an active profile here?
  describe '#deactivate_for_gpo_verification' do
    it 'sets a timestamp for gpo_verification_pending_at' do
      profile = create(:profile, user: user)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false) # ???
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil # to change
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      profile.deactivate_for_gpo_verification

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_present # changed
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      expect(profile).to_not be_active
      expect(profile.gpo_verification_pending_at).to be_present
    end
  end

  describe '#deactivate_for_in_person_verification_cancelled' do
    it 'deactivates a profile for cancelling in_person_verification' do
      profile = create(:profile, :in_person_verification_pending, user: user)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('in_person_verification_pending') # to change
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_present # to change
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      profile.deactivate_for_in_person_verification_cancelled

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('verification_cancelled') # changed
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil # changed
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil
    end
  end

  describe '#deactivate_for_verify_by_mail_cancelled' do
    it 'deactivates a profile for cancelling verify by mail' do
      profile = create(:profile, :verify_by_mail_pending, user: user)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil # to change
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_present # to change
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      profile.deactivate_for_verify_by_mail_cancelled

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to eq('verification_cancelled') # changed
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil # changed
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil
    end
  end

  # TODO: does deactivating make sense for a non-active profile? Should we prevent it?
  # TODO: related: should we test against an active profile here?
  describe '#deactivate_for_fraud_review' do
    it 'sets fraud_review_pending to true and sets fraud_pending_reason' do
      profile = create(:profile, user: user)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false) # ???
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false) # to change
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      profile.fraud_pending_reason = 'threatmetrix_review'
      profile.deactivate_for_fraud_review

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(true) # changed
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      expect(profile).to_not be_active
      expect(profile.fraud_review_pending?).to eq(true)
      expect(profile.fraud_rejection?).to eq(false)
      expect(profile.fraud_pending_reason).to eq('threatmetrix_review')
    end
  end

  describe '#bump_fraud_review_pending_timestamps' do
    context 'a profile is fraud review pending' do
      it 'updates the fraud review pending timestamp' do
        profile = create(:profile, :fraud_review_pending, user: user)

        profile.bump_fraud_review_pending_timestamps

        expect(profile).to_not be_active
        expect(profile.fraud_review_pending?).to eq(true)
        expect(profile.fraud_rejection?).to eq(false)
        expect(profile.fraud_pending_reason).to eq('threatmetrix_review')
      end
    end

    context 'a profile is fraud review rejected' do
      it 'removes the fraud rejection timestamp and updates the fraud review pending timestamp' do
        profile = create(:profile, :fraud_rejection, user: user)

        profile.bump_fraud_review_pending_timestamps

        expect(profile).to_not be_active
        expect(profile.fraud_review_pending?).to eq(true)
        expect(profile.fraud_rejection?).to eq(false)
        expect(profile.fraud_pending_reason).to eq('threatmetrix_review')
      end
    end
  end

  describe '#reject_for_fraud' do
    before do
      # This is necessary because UserMailer reaches into the
      # controller's params. As this is a model spec, we have to fake
      # the params object.
      fake_params = ActionController::Parameters.new(
        user: OpenStruct.new(id: 'fake_user_id'),
        email_address: OpenStruct.new(user_id: 'fake_user_id', email: 'fake_user@test.com'),
      )
      allow_any_instance_of(UserMailer).to receive(:params).and_return(fake_params)
    end

    context 'it notifies the user' do
      let(:profile) do
        profile = create(:profile, :fraud_review_pending, user: user)
        profile.reject_for_fraud(notify_user: true)
        profile
      end

      it 'sets fraud_rejection to true' do
        expect(profile).to_not be_active
      end

      it 'sends an email' do
        expect { profile }.to change(ActionMailer::Base.deliveries, :count).by(1)
      end

      it 'sets the fraud_rejection_at timestamp' do
        expect(profile.fraud_rejection_at).to be_present
      end
    end

    context 'it does not notify the user' do
      let(:profile) do
        profile = create(:profile, :fraud_review_pending, user: user)
        profile.reject_for_fraud(notify_user: false)
        profile
      end

      it 'does not send an email' do
        expect(profile).to_not be_active

        expect { profile }.to change(ActionMailer::Base.deliveries, :count).by(0)
      end
    end

    context 'when the SP is the IRS' do
      let(:sp) { create(:service_provider, :irs) }
      let(:profile) do
        create(:profile, :fraud_review_pending, active: false, initiating_service_provider: sp)
      end

      context 'and notify_user is true' do
        it 'logs an event with manual_reject' do
          allow(IdentityConfig.store).to receive(:irs_attempt_api_track_idv_fraud_review).
            and_return(true)

          expect(profile.initiating_service_provider.irs_attempts_api_enabled?).to be_truthy

          expect(profile.irs_attempts_api_tracker).to receive(:fraud_review_adjudicated).
            with(
              hash_including(decision: 'manual_reject'),
            )

          profile.reject_for_fraud(notify_user: true)
        end
      end

      context 'and notify_user is false' do
        it 'logs an event with automatic_reject' do
          allow(IdentityConfig.store).to receive(:irs_attempt_api_enabled).and_return(true)
          allow(IdentityConfig.store).to receive(:irs_attempt_api_track_idv_fraud_review).
            and_return(true)

          expect(profile.initiating_service_provider.irs_attempts_api_enabled?).to be_truthy

          expect(profile.irs_attempts_api_tracker).to receive(:fraud_review_adjudicated).
            with(
              hash_including(decision: 'automatic_reject'),
            )

          profile.reject_for_fraud(notify_user: false)
        end
      end
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
