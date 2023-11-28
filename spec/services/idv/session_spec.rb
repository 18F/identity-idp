require 'rails_helper'

RSpec.describe Idv::Session do
  let(:user) { create(:user) }
  let(:user_session) { {} }

  subject do
    Idv::Session.new(user_session: user_session, current_user: user, service_provider: nil)
  end

  describe '#initialize' do
    context 'without idv user session' do
      it 'initializes user session' do
        expect_any_instance_of(Idv::Session).to receive(:new_idv_session).twice.and_call_original

        subject

        expect(user_session[:idv]).to eq(subject.new_idv_session)
      end
    end

    # FlowStateMachine related specs, can be removed when FSM is gone
    context 'with idv user session' do
      let(:idv_session) { { vendor_phone_confirmation: true } }
      let(:user_session) { { idv: idv_session } }

      it 'does not initialize user session' do
        expect_any_instance_of(Idv::Session).not_to receive(:new_idv_session)

        subject

        expect(user_session[:idv]).to eq(idv_session)
      end
    end

    context 'with empty idv user session' do
      let(:idv_session) { {} }
      let(:user_session) { { idv: idv_session } }

      it 'does not initialize user session' do
        expect_any_instance_of(Idv::Session).not_to receive(:new_idv_session)

        subject

        expect(user_session[:idv]).to eq(idv_session)
      end
    end
  end

  describe '#method_missing' do
    it 'disallows un-supported attributes' do
      expect { subject.foo = 'bar' }.to raise_error NoMethodError
    end

    it 'allows supported attributes' do
      Idv::Session::VALID_SESSION_ATTRIBUTES.each do |attr|
        subject.send attr, 'foo'
        expect(subject.send(attr)).to eq 'foo'
        subject.send "#{attr}=".to_sym, 'foo'
        expect(subject.send(attr)).to eq 'foo'
      end
    end
  end

  describe '#respond_to_missing?' do
    it 'disallows un-supported attributes' do
      expect(subject.respond_to?(:foo=, false)).to eq false
    end

    it 'allows supported attributes' do
      Idv::Session::VALID_SESSION_ATTRIBUTES.each do |attr|
        expect(subject.respond_to?(attr, false)).to eq true
        expect(subject.respond_to?("#{attr}=".to_sym, false)).to eq true
      end
    end
  end

  describe '#acknowledge_personal_key!' do
    before do
      subject.personal_key = 'ABCD1234'
    end
    it 'clears personal_key' do
      expect { subject.acknowledge_personal_key! }.to change { subject.personal_key }.to eql(nil)
    end
    it 'sets personal_key_acknowledged' do
      expect { subject.acknowledge_personal_key! }.to change {
                                                        subject.personal_key_acknowledged
                                                      }.from(nil).to eql(true)
    end
  end

  describe '#invalidate_personal_key!' do
    before do
      subject.personal_key = 'ABCD-1234'
      subject.personal_key_acknowledged = true
      subject.invalidate_personal_key!
    end
    it 'nils out personal_key' do
      expect(subject.personal_key).to be_nil
    end
    it 'nils out personal_key-acknowledged' do
      expect(subject.personal_key).to be_nil
    end
  end

  describe '#add_failed_phone_step_number' do
    it 'adds uniq phone numbers in e164 format' do
      subject.add_failed_phone_step_number('+1703-555-1212')
      subject.add_failed_phone_step_number('703555-7575')

      expect(subject.failed_phone_step_numbers.length).to eq(2)

      # add duplicates
      subject.add_failed_phone_step_number('(703) 555-1234')
      subject.add_failed_phone_step_number('1703555-1212')

      expect(subject.failed_phone_step_numbers).to eq(
        ['+17035551212', '+17035557575', '+17035551234'],
      )
    end
  end

  describe '#failed_phone_step_numbers' do
    it 'defaults to an empy array' do
      expect(subject.failed_phone_step_numbers).to eq([])
    end
  end

  describe '#create_profile_from_applicant_with_password' do
    before do
      subject.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN
    end

    context 'with phone verifed by vendor' do
      before do
        subject.address_verification_mechanism = 'phone'
        subject.vendor_phone_confirmation = true
        subject.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE
      end

      it 'completes the profile if the user has completed OTP phone confirmation' do
        freeze_time do
          now = Time.zone.now

          subject.user_phone_confirmation = true
          subject.create_profile_from_applicant_with_password(user.password)
          profile = subject.profile

          expect(profile.activated_at).to eq now
          expect(profile.active).to eq true
          expect(profile.deactivation_reason).to eq nil
          expect(profile.fraud_review_pending?).to eq(false)
          expect(profile.gpo_verification_pending_at.present?).to eq false
          expect(profile.initiating_service_provider).to eq nil
          expect(profile.verified_at).to eq now

          pii_from_session = Pii::Cacher.new(user, user_session).fetch
          expect(pii_from_session).to_not be_nil
          expect(pii_from_session.ssn).to eq(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn])
        end
      end

      it 'does not complete the profile if the user has not completed OTP phone confirmation' do
        subject.user_phone_confirmation = nil
        subject.create_profile_from_applicant_with_password(user.password)
        profile = subject.profile

        expect(profile.activated_at).to eq nil
        expect(profile.active).to eq false
        expect(profile.deactivation_reason).to eq nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at.present?).to eq true
        expect(profile.initiating_service_provider).to eq nil
        expect(profile.verified_at).to eq nil

        pii_from_session = Pii::Cacher.new(user, user_session).fetch
        expect(pii_from_session).to_not be_nil
        expect(pii_from_session.ssn).to eq(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn])
      end

      context 'with establishing in person enrollment' do
        let!(:enrollment) do
          create(:in_person_enrollment, :establishing, user: user, profile: nil)
        end

        before do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          subject.user_phone_confirmation = true
          subject.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.with_indifferent_access
        end

        it 'sets profile to pending in person verification' do
          subject.create_profile_from_applicant_with_password(user.password)
          profile = subject.profile

          expect(profile.activated_at).to eq nil
          expect(profile.active).to eq false
          expect(profile.in_person_verification_pending?).to eq(true)
          expect(profile.fraud_review_pending?).to eq(false)
          expect(profile.gpo_verification_pending_at.present?).to eq false
          expect(profile.initiating_service_provider).to eq nil
          expect(profile.verified_at).to eq nil

          pii_from_session = Pii::Cacher.new(user, user_session).fetch
          expect(pii_from_session).to_not be_nil
          expect(pii_from_session.ssn).to eq(Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE[:ssn])
        end

        it 'creates a USPS enrollment' do
          expect(UspsInPersonProofing::EnrollmentHelper).
            to receive(:schedule_in_person_enrollment).
            with(user, Pii::Attributes.new_from_hash(subject.applicant))

          subject.create_profile_from_applicant_with_password(user.password)

          profile = enrollment.reload.profile
          expect(profile).to eq(user.profiles.last)
          expect(profile.activated_at).to eq nil
          expect(profile.active).to eq false
          expect(profile.in_person_verification_pending?).to eq(true)
          expect(profile.fraud_review_pending?).to eq(false)
          expect(profile.gpo_verification_pending_at.present?).to eq false
          expect(profile.initiating_service_provider).to eq nil
          expect(profile.verified_at).to eq nil
        end
      end
    end

    context 'with gpo address verification' do
      before do
        subject.address_verification_mechanism = 'gpo'
        subject.vendor_phone_confirmation = false
      end

      it 'sets profile to pending gpo verification' do
        subject.create_profile_from_applicant_with_password(user.password)
        profile = subject.profile

        expect(profile.activated_at).to eq nil
        expect(profile.active).to eq false
        expect(profile.deactivation_reason).to eq nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at.present?).to eq true
        expect(profile.initiating_service_provider).to eq nil
        expect(profile.verified_at).to eq nil

        pii_from_session = Pii::Cacher.new(user, user_session).fetch
        expect(pii_from_session).to_not be_nil
        expect(pii_from_session.ssn).to eq(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn])
      end
    end

    context 'without a confirmed phone number' do
      before do
        subject.address_verification_mechanism = 'phone'
        subject.vendor_phone_confirmation = false
      end

      it 'does not complete the user profile' do
        subject.create_profile_from_applicant_with_password(user.password)
        profile = subject.profile

        expect(profile.activated_at).to eq nil
        expect(profile.active).to eq false
        expect(profile.deactivation_reason).to eq nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at.present?).to eq true
        expect(profile.initiating_service_provider).to eq nil
        expect(profile.verified_at).to eq nil

        pii_from_session = Pii::Cacher.new(user, user_session).fetch
        expect(pii_from_session).to_not be_nil
        expect(pii_from_session.ssn).to eq(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn])
      end
    end
  end

  describe '#phone_confirmed?' do
    it 'returns true if the user and vendor have confirmed the phone' do
      subject.user_phone_confirmation = true
      subject.vendor_phone_confirmation = true

      expect(subject.phone_confirmed?).to eq(true)
    end

    it 'returns false if the user has not confirmed the phone' do
      subject.user_phone_confirmation = nil
      subject.vendor_phone_confirmation = true

      expect(subject.phone_confirmed?).to eq(false)
    end

    it 'returns false if the vendor has not confirmed the phone' do
      subject.user_phone_confirmation = true
      subject.vendor_phone_confirmation = nil

      expect(subject.phone_confirmed?).to eq(false)
    end

    it 'returns false if neither the user nor the vendor has confirmed the phone' do
      subject.user_phone_confirmation = nil
      subject.vendor_phone_confirmation = nil

      expect(subject.phone_confirmed?).to eq(false)
    end
  end

  describe '#profile' do
    it 'is nil by default' do
      expect(subject.profile).to eql(nil)
    end

    it 'can be set via profile_id' do
      profile = create(:profile)
      subject.profile_id = profile.id
      expect(subject.profile).to eql(profile)
    end

    it 'can be changed' do
      profile1 = create(:profile)
      profile2 = create(:profile)

      subject.profile_id = profile1.id
      expect(subject.profile).to eql(profile1)

      subject.profile_id = profile2.id
      expect(subject.profile).to eql(profile2)
    end
  end

  describe '#address_mechanism_chosen?' do
    context 'phone verification chosen' do
      before do
        subject.address_verification_mechanism = 'phone'
      end

      it 'returns true if the vendor has confirmed the phone number' do
        subject.vendor_phone_confirmation = true

        expect(subject.address_mechanism_chosen?).to eq(true)
      end

      it 'returns false if the vendor has not confirmed the phone number' do
        subject.vendor_phone_confirmation = nil

        expect(subject.address_mechanism_chosen?).to eq(false)
      end
    end

    it 'returns true if the user has selected gpo address verification' do
      subject.address_verification_mechanism = 'gpo'

      expect(subject.address_mechanism_chosen?).to eq(true)
    end

    it 'returns false if the user has not selected phone or gpo address verification' do
      subject.address_verification_mechanism = nil

      expect(subject.address_mechanism_chosen?).to eq(false)
    end
  end
end
