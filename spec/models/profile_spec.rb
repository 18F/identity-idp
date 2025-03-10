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

  describe '#in_person_verification_pending?' do
    it 'returns true if the in_person_verification_pending_at is present' do
      profile = create(
        :profile,
        :in_person_verification_pending,
        user: user,
      )

      allow(profile).to receive(:update!).and_raise(RuntimeError)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil
      expect(profile.in_person_verification_pending_at).to be_present
      expect(profile.in_person_verification_pending?).to eq(true)
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
      expect(profile.encrypted_pii_recovery_multi_region).to be_nil

      initial_personal_key = user.encrypted_recovery_code_digest_multi_region

      encrypt_pii

      expect(profile.encrypted_pii_recovery).to be_present
      expect(profile.encrypted_pii_recovery_multi_region).to be_present

      user.reload
      expect(user.encrypted_recovery_code_digest).to_not be_present
      expect(user.encrypted_recovery_code_digest_multi_region).to_not eq initial_personal_key
    end

    it 'updates the personal key digest generation time' do
      user.encrypted_recovery_code_digest_generated_at = nil

      encrypt_pii

      expect(user.reload.encrypted_recovery_code_digest_generated_at.to_i)
        .to be_within(1).of(Time.zone.now.to_i)
    end

    context 'ssn fingerprinting' do
      it 'fingerprints the ssn' do
        expect { encrypt_pii }
          .to change { profile.ssn_signature }
          .from(nil).to(Pii::Fingerprinter.fingerprint(ssn))
      end

      context 'ssn is blank' do
        let(:ssn) { nil }

        it 'does not fingerprint the SSN' do
          expect { encrypt_pii }
            .to_not change { profile.ssn_signature }
            .from(nil)
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

      expect { encrypt_pii }
        .to change { profile.name_zip_birth_year_signature }
        .from(nil).to(fingerprint)
    end

    context 'when a part of the compound PII key is missing' do
      let(:dob) { nil }

      it 'does not write a fingerprint' do
        expect { encrypt_pii }
          .to_not change { profile.name_zip_birth_year_signature }
          .from(nil)
      end
    end
  end

  describe '#encrypt_recovery_pii' do
    it 'generates new personal key' do
      expect(profile.encrypted_pii_recovery).to be_nil
      expect(profile.encrypted_pii_recovery_multi_region).to be_nil

      initial_personal_key = user.encrypted_recovery_code_digest_multi_region

      profile.encrypt_recovery_pii(pii)

      expect(profile.encrypted_pii_recovery).to be_present
      expect(profile.encrypted_pii_recovery_multi_region).to be_present

      user.reload
      expect(user.encrypted_recovery_code_digest).to_not be_present
      expect(user.encrypted_recovery_code_digest_multi_region).to_not eq initial_personal_key
      expect(profile.personal_key).to_not eq user.encrypted_recovery_code_digest_multi_region
    end

    it 'can be passed a personal key' do
      expect(profile.encrypted_pii_recovery).to be_nil
      expect(profile.encrypted_pii_recovery_multi_region).to be_nil

      personal_key = 'ABCD-1234'
      returned_personal_key = profile.encrypt_recovery_pii(pii, personal_key: personal_key)

      expect(returned_personal_key).to eql(personal_key)

      expect(profile.encrypted_pii_recovery).to be_present
      expect(profile.encrypted_pii_recovery_multi_region).to be_present
      expect(profile.personal_key).to eq personal_key
    end
  end

  describe '#decrypt_pii' do
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

    it 'fails if the encryption context from the uuid is incorrect' do
      profile.encrypt_pii(pii, user.password)

      allow(profile.user).to receive(:uuid).and_return('a-different-uuid')

      expect { profile.decrypt_pii(user.password) }.to raise_error(Encryption::EncryptionError)
    end
  end

  describe '#recover_pii' do
    it 'decrypts recovery PII with personal key for users with a multi region ciphertext' do
      profile.encrypt_pii(pii, user.password)
      personal_key = profile.personal_key

      normalized_personal_key = PersonalKeyGenerator.new(user).normalize(personal_key)

      expect(profile.encrypted_pii_recovery_multi_region).to_not be_nil

      decrypted_pii = profile.recover_pii(normalized_personal_key)

      expect(decrypted_pii).to eq pii
    end

    it 'decrypts recovery PII with personal key for users with only a single region ciphertext' do
      profile.encrypt_pii(pii, user.password)
      profile.update!(encrypted_pii_recovery_multi_region: nil)
      personal_key = profile.personal_key

      normalized_personal_key = PersonalKeyGenerator.new(user).normalize(personal_key)

      decrypted_pii = profile.recover_pii(normalized_personal_key)

      expect(decrypted_pii).to eq pii
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
      expect { user.profiles.create!(active: true) }
        .to raise_error(ActiveRecord::RecordInvalid)
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

    context 'when a user creates a facial match comparision profile' do
      context 'when the user has an active profile' do
        it 'creates a facial match upgrade record' do
          profile.activate
          facial_match_profile = create(
            :profile,
            :facial_match_proof,
            user: user,
          )

          expect { facial_match_profile.activate }.to(
            change do
              SpUpgradedFacialMatchProfile.count
            end.by(1),
          )
        end
      end

      context 'when the user has an active facial match profile' do
        it 'does not create a facial match conversion record' do
          create(:profile, :active, :facial_match_proof, user: user)

          facial_match_reproof = create(:profile, :facial_match_proof, user: user)
          expect { facial_match_reproof.activate }.to_not(
            change do
              SpUpgradedFacialMatchProfile.count
            end,
          )
        end
      end

      context 'when the user does not have an active profile' do
        it 'does not create a facial match conversion record' do
          profile = create(:profile, :facial_match_proof, user: user)

          expect { profile.activate }.to_not(change { SpUpgradedFacialMatchProfile.count })
        end
      end
    end

    it 'does not create a facial match upgrade record for a non-facial match profile' do
      expect { profile.activate }.to_not(change { SpUpgradedFacialMatchProfile.count })
    end

    it 'sends a reproof completed push event' do
      profile = create(:profile, :active, user: user)
      expect(PushNotification::HttpPush).to receive(:deliver)
        .with(PushNotification::ReproofCompletedEvent.new(user: user))

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

  describe '#deactivate_due_to_encryption_error' do
    context 'when the profile has a "pending" in_person_enrollment' do
      subject { create(:profile, :in_person_verification_pending, user: user) }

      before do
        subject.deactivate_due_to_encryption_error
      end

      it 'deactivates with reason encryption_error' do
        expect(subject).to have_attributes(
          active: false,
          deactivation_reason: 'encryption_error',
          in_person_verification_pending_at: be_kind_of(Time),
        )
      end

      it 'cancels the associated pending in_person_enrollment' do
        expect(subject.in_person_enrollment.status).to eq('cancelled')
      end
    end

    context 'when the profile has a "passed" in_person_enrollment' do
      subject { create(:profile, :active, user: user) }
      let!(:enrollment) do
        create(:in_person_enrollment, user: user, profile: subject, status: :passed)
      end

      before do
        subject.deactivate_due_to_encryption_error
      end

      it 'deactivates with reason encryption_error' do
        expect(subject).to have_attributes(
          active: false,
          deactivation_reason: 'encryption_error',
        )
      end

      it 'does not cancel the associated pending in_person_enrollment' do
        expect(subject.in_person_enrollment.status).to eq('passed')
      end
    end

    context 'when the profile has no in_person_enrollment' do
      subject { create(:profile, :active, user: user) }

      before do
        subject.deactivate_due_to_encryption_error
      end

      it 'deactivates with reason encryption_error' do
        expect(subject).to have_attributes(
          active: false,
          deactivation_reason: 'encryption_error',
        )
      end
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

  describe '#clear_password_reset_deactivation_reason' do
    context 'when the profile has the password_reset deactivation reason' do
      context 'when the profile was previously active' do
        subject { create(:profile, :active, user: user) }

        before do
          subject.deactivate(:password_reset)
          subject.clear_password_reset_deactivation_reason
        end

        it 'removes "password_reset" deactivation reason from the profile' do
          expect(subject.deactivation_reason).to be_nil
        end

        it 'activates the profile' do
          expect(subject.active?).to be(true)
        end
      end

      context 'when the profile was not previously active' do
        subject { create(:profile, :in_person_verification_pending, user: user) }

        before do
          subject.deactivate(:password_reset)
          subject.clear_password_reset_deactivation_reason
        end

        it 'removes "password_reset" deactivation reason from the profile' do
          expect(subject.deactivation_reason).to be_nil
        end

        it 'does not activate the profile' do
          expect(subject.active?).to be(false)
        end
      end
    end

    context 'when the profile does not have the password_reset deactivation reason' do
      subject { create(:profile, :encryption_error, user: user) }

      before do
        subject.clear_password_reset_deactivation_reason
      end

      it 'does not remove the deactivation reason from the profile' do
        expect(subject.deactivation_reason).to eq('encryption_error')
      end

      it 'does not activate the profile' do
        expect(subject.active?).to be(false)
      end
    end
  end

  describe '#activate_after_passing_in_person' do
    let(:current_time) { Time.zone.now }

    context 'when the profile does not have any reason not to activate' do
      let(:profile) do
        create(
          :profile,
          :in_person_verification_pending,
          user: user,
        )
      end

      before do
        freeze_time do
          travel_to(current_time)
          profile.activate_after_passing_in_person
        end
      end

      it 'activates a profile' do
        expect(profile).to have_attributes(
          activated_at: current_time,
          active: true,
          deactivation_reason: nil,
          gpo_verification_pending_at: nil,
          in_person_verification_pending_at: nil,
          initiating_service_provider: nil,
          verified_at: current_time,
          fraud_review_pending_at: nil,
          fraud_rejection_at: nil,
          fraud_pending_reason: nil,
        )
      end
    end

    context 'when the profile has a pending reason not to activate' do
      let(:profile) do
        create(
          :profile,
          :fraud_review_pending,
          :in_person_verification_pending,
          user: user,
        )
      end

      before do
        profile.activate_after_passing_in_person
      rescue => err
        @error = err
      ensure
        profile.reload
      end

      it 'throws an "Attempting to activate a profile with pending reason:" error' do
        expect(@error.message).to eq(
          'Attempting to activate profile with pending reasons: fraud_check_pending',
        )
      end

      it 'does not activate the profile' do
        expect(profile).to have_attributes(
          active: false,
          activated_at: nil,
          deactivation_reason: nil,
          gpo_verification_pending_at: nil,
          in_person_verification_pending_at: kind_of(Time),
          initiating_service_provider: nil,
          verified_at: nil,
          fraud_review_pending_at: kind_of(Time),
          fraud_rejection_at: nil,
          fraud_pending_reason: 'threatmetrix_review',
        )
      end
    end

    context 'when the profile has a deactivation reason not to activate' do
      let(:profile) do
        create(
          :profile,
          :encryption_error,
          :in_person_verification_pending,
          user: user,
        )
      end

      before do
        profile.activate_after_passing_in_person
      rescue => err
        @error = err
      ensure
        profile.reload
      end

      it 'throws an "Attempting to activate a profile with deactivation reason:" error' do
        expect(@error.message).to eq(
          'Attempting to activate profile with deactivation reason: encryption_error',
        )
      end

      it 'does not activate the profile' do
        expect(profile).to have_attributes(
          active: false,
          activated_at: nil,
          deactivation_reason: 'encryption_error',
          gpo_verification_pending_at: nil,
          in_person_verification_pending_at: kind_of(Time),
          initiating_service_provider: nil,
          verified_at: nil,
          fraud_review_pending_at: nil,
          fraud_rejection_at: nil,
          fraud_pending_reason: nil,
        )
      end
    end

    context 'when an update error occurs' do
      let(:profile) { create(:profile, :in_person_verification_pending, user: user) }

      before do
        allow(profile).to receive(:update!).and_raise(RuntimeError)

        suppress(RuntimeError) do
          profile.activate_after_passing_in_person
        end
      end

      it 'does not activate the profile' do
        expect(profile).to have_attributes(
          active: false,
          activated_at: nil,
          deactivation_reason: nil,
          gpo_verification_pending_at: nil,
          in_person_verification_pending_at: kind_of(Time),
          initiating_service_provider: nil,
          verified_at: nil,
          fraud_review_pending_at: nil,
          fraud_rejection_at: nil,
          fraud_pending_reason: nil,
        )
      end
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
  describe 'deactivate_for_in_person_verification' do
    it 'deactivates a profile for in_person_verification' do
      profile = create(:profile, user: user)

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil
      expect(profile.fraud_review_pending?).to eq(false)
      expect(profile.gpo_verification_pending_at).to be_nil
      expect(profile.in_person_verification_pending_at).to be_nil
      expect(profile.initiating_service_provider).to be_nil
      expect(profile.verified_at).to be_nil

      profile.deactivate_for_in_person_verification

      expect(profile.activated_at).to be_nil
      expect(profile.active).to eq(false)
      expect(profile.deactivation_reason).to be_nil
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

  # TODO: does deactivating make sense for a non-active profile? Should we prevent it?
  # TODO: related: should we test against an active profile here?
  describe '#deactivate_for_fraud_review' do
    it 'sets fraud_review_pending to true and sets fraud_pending_reason' do
      profile = create(:profile, :in_person_verification_pending, user: user)

      profile.fraud_pending_reason = 'threatmetrix_review'
      expect { profile.deactivate_for_fraud_review }.to(
        change { profile.fraud_review_pending? }.from(false).to(true)
        .and(change { profile.in_person_verification_pending_at }.to(nil)),
      )

      expect(profile).to_not be_active
      expect(profile.fraud_rejection?).to eq(false)
      expect(profile.fraud_pending_reason).to eq('threatmetrix_review')
      expect(profile.pending_reasons).to eq([:fraud_check_pending])
    end
  end

  describe '#deactivate_due_to_in_person_verification_cancelled' do
    let(:profile) { create(:profile, :in_person_verification_pending) }
    context 'when the profile does not have a deactivation reason' do
      it 'updates the profile and sets the deactivation reason to "verification_cancelled"' do
        expect(profile.deactivation_reason).to be_nil
        profile.deactivate_due_to_in_person_verification_cancelled

        expect(profile.active).to be false
        expect(profile.deactivation_reason).to eq('verification_cancelled')
        expect(profile.in_person_verification_pending_at).to be nil
      end
    end

    context 'when the profile has a deactivation reason' do
      it 'updates the profile without overwriting the deactivation reason (encryption_error)' do
        profile.deactivation_reason = 'encryption_error'
        expect(profile.deactivation_reason).to_not be_nil

        profile.deactivate_due_to_in_person_verification_cancelled

        expect(profile.active).to be false
        expect(profile.deactivation_reason).to eq('encryption_error')
        expect(profile.in_person_verification_pending_at).to be nil
      end

      it 'updates the profile without overwriting the deactivation reason (password_reset)' do
        profile.deactivation_reason = 'password_reset'
        expect(profile.deactivation_reason).to_not be_nil

        profile.deactivate_due_to_in_person_verification_cancelled

        expect(profile.active).to be false
        expect(profile.deactivation_reason).to eq('password_reset')
        expect(profile.in_person_verification_pending_at).to be nil
      end
    end
  end

  describe '#deactivate_due_to_gpo_expiration' do
    let(:profile) { create(:profile, :verify_by_mail_pending, user: user) }

    it 'sets gpo_verification_expired_at' do
      freeze_time do
        expect do
          profile.deactivate_due_to_gpo_expiration
        end.to change { profile.gpo_verification_expired_at }.to eql(Time.zone.now)
      end
    end

    it 'clears gpo_verification_pending_at' do
      expect do
        profile.deactivate_due_to_gpo_expiration
      end.to change { profile.gpo_verification_pending_at }.to eql(nil)
    end

    it 'maintains active = false' do
      expect do
        profile.deactivate_due_to_gpo_expiration
      end.not_to change { profile.active }.from(false)
    end

    it 'does not set a deactivation_reason' do
      expect do
        profile.deactivate_due_to_gpo_expiration
      end.not_to change { profile.deactivation_reason }.from(nil)
    end

    context 'not pending gpo' do
      let(:profile) { create(:profile, user: user) }
      it 'raises' do
        expect do
          profile.deactivate_due_to_gpo_expiration
        end.to raise_error
      end
    end
  end

  describe '#reject_for_fraud' do
    before do
      # This is necessary because UserMailer reaches into the
      # controller's params. As this is a model spec, we have to fake
      # the params object.
      fake_params = ActionController::Parameters.new(
        user: User.new(id: 'fake_user_id'),
        email_address: EmailAddress.new(user_id: 'fake_user_id', email: 'fake_user@test.com'),
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
  end

  describe '#profile_age_in_seconds' do
    it 'logs the time since the created_at timestamp', :freeze_time do
      profile = create(:profile, created_at: 5.minutes.ago)

      expect(profile.profile_age_in_seconds).to eq(5.minutes.to_i)
    end
  end

  describe 'query class methods' do
    describe '.active' do
      it 'returns only active Profiles' do
        user.profiles.create(active: false)
        user.profiles.create(active: true)
        expect(user.profiles.active.count).to eq 1
      end
    end

    describe '.verified' do
      it 'returns only verified Profiles' do
        user.profiles.create(verified_at: Time.zone.now)
        user.profiles.create(verified_at: nil)
        expect(user.profiles.verified.count).to eq 1
      end
    end

    describe '.fraud_rejection' do
      it 'returns only fraud_rejection Profiles' do
        user.profiles.create(fraud_rejection_at: Time.zone.now)
        user.profiles.create(fraud_rejection_at: nil)
        expect(user.profiles.fraud_rejection.count).to eq 1
      end
    end

    describe '.fraud_review_pending' do
      it 'returns only fraud_review_pending Profiles' do
        user.profiles.create(fraud_review_pending_at: Time.zone.now)
        user.profiles.create(fraud_review_pending_at: nil)
        expect(user.profiles.fraud_review_pending.count).to eq 1
      end
    end

    describe '.gpo_verification_pending' do
      it 'returns only gpo_verification_pending Profiles' do
        user.profiles.create(gpo_verification_pending_at: Time.zone.now)
        user.profiles.create(gpo_verification_pending_at: nil)
        expect(user.profiles.gpo_verification_pending.count).to eq 1
      end
    end

    describe '.in_person_verification_pending' do
      it 'returns only in_person_verification_pending Profiles' do
        user.profiles.create(in_person_verification_pending_at: Time.zone.now)
        user.profiles.create(in_person_verification_pending_at: nil)
        expect(user.profiles.in_person_verification_pending.count).to eq 1
      end
    end
  end
end
