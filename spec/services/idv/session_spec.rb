require 'rails_helper'

RSpec.describe Idv::Session do
  let(:user) { create(:user) }
  let(:user_session) { {} }

  subject do
    Idv::Session.new(user_session: user_session, current_user: user, service_provider: nil)
  end

  describe '#initialize' do
    context 'without idv user session' do
      it 'initializes user session with empty hash' do
        subject

        expect(user_session[:idv]).to eq({})
      end
    end

    # FlowStateMachine related specs, can be removed when FSM is gone
    context 'with idv user session' do
      let(:idv_session) { { vendor_phone_confirmation: true } }
      let(:user_session) { { idv: idv_session } }

      it 'does not initialize user session' do
        expect(subject).not_to receive(:new_idv_session)

        subject

        expect(user_session[:idv]).to eq(idv_session)
      end
    end

    context 'with empty idv user session' do
      let(:idv_session) { {} }
      let(:user_session) { { idv: idv_session } }

      it 'does not initialize user session' do
        expect(subject).not_to receive(:new_idv_session)

        subject

        expect(user_session[:idv]).to eq(idv_session)
      end
    end
  end

  describe 'attribute methods' do
    it 'disallows un-supported setters' do
      expect { subject.foo = 'bar' }.to raise_error NoMethodError
    end

    it 'allows using supported setters and getters' do
      Idv::Session::VALID_SESSION_ATTRIBUTES.each do |attr|
        expect(subject.send(attr)).to eq nil
        subject.send :"#{attr}=", 'foo'
        expect(subject.send(attr)).to eq 'foo'
      end
    end

    it 'allows checking for un-supported attributes' do
      expect(subject.respond_to?(:foo=, false)).to eq false
    end

    it 'allows checking for supported attributes' do
      Idv::Session::VALID_SESSION_ATTRIBUTES.each do |attr|
        expect(subject.respond_to?(attr, false)).to eq true
        expect(subject.respond_to?(:"#{attr}=", false)).to eq true
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
    let(:is_enhanced_ipp) { false }
    let(:proofing_components) { { document_check: 'mock' } }
    let(:opt_in_param) { nil }

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
          subject.create_profile_from_applicant_with_password(
            user.password, is_enhanced_ipp:, proofing_components:
          )
          profile = subject.profile

          expect(profile.activated_at).to eq now
          expect(profile.active).to eq true
          expect(profile.deactivation_reason).to eq nil
          expect(profile.fraud_review_pending?).to eq(false)
          expect(profile.gpo_verification_pending_at.present?).to eq false
          expect(profile.initiating_service_provider).to eq nil
          expect(profile.verified_at).to eq now

          pii_from_session = Pii::Cacher.new(user, user_session).fetch(profile.id)
          expect(pii_from_session).to_not be_nil
          expect(pii_from_session.ssn).to eq(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn])
        end
      end

      it 'does not complete the profile if the user has not completed OTP phone confirmation' do
        subject.user_phone_confirmation = nil
        subject.create_profile_from_applicant_with_password(
          user.password, is_enhanced_ipp:, proofing_components:
        )
        profile = subject.profile

        expect(profile.activated_at).to eq nil
        expect(profile.active).to eq false
        expect(profile.deactivation_reason).to eq nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at.present?).to eq true
        expect(profile.initiating_service_provider).to eq nil
        expect(profile.verified_at).to eq nil

        pii_from_session = Pii::Cacher.new(user, user_session).fetch(profile.id)
        expect(pii_from_session).to_not be_nil
        expect(pii_from_session.ssn).to eq(Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn])
      end

      context 'when the user has an establishing in person enrollment' do
        let!(:enrollment) do
          create(:in_person_enrollment, :establishing, user: user)
        end
        let(:profile) { subject.profile }

        before do
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          subject.user_phone_confirmation = true
          subject.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.with_indifferent_access
        end

        context 'when the USPS enrollment is successful' do
          before do
            allow(UspsInPersonProofing::EnrollmentHelper).to receive(:schedule_in_person_enrollment)
          end

          it 'creates an USPS enrollment' do
            subject.create_profile_from_applicant_with_password(
              user.password, is_enhanced_ipp:, proofing_components:
            )
            expect(UspsInPersonProofing::EnrollmentHelper).to have_received(
              :schedule_in_person_enrollment,
            ).with(
              user: user,
              pii: Pii::Attributes.new_from_hash(subject.applicant),
              is_enhanced_ipp: is_enhanced_ipp,
              opt_in: opt_in_param,
            )
          end

          it 'creates a profile with in person verification pending' do
            subject.create_profile_from_applicant_with_password(
              user.password, is_enhanced_ipp:, proofing_components:
            )
            expect(profile).to have_attributes(
              {
                activated_at: nil,
                active: false,
                in_person_verification_pending?: true,
                fraud_review_pending?: false,
                gpo_verification_pending_at: nil,
                initiating_service_provider: nil,
                verified_at: nil,
              },
            )
          end

          it 'saves the pii to the session' do
            subject.create_profile_from_applicant_with_password(
              user.password, is_enhanced_ipp:, proofing_components:
            )
            expect(Pii::Cacher.new(user, user_session).fetch(profile.id)).to_not be_nil
          end

          it 'associates the in person enrollment with the created profile' do
            subject.create_profile_from_applicant_with_password(
              user.password, is_enhanced_ipp:, proofing_components:
            )
            expect(enrollment.reload.profile_id).to eq(profile.id)
          end

          context 'when the in person enrollment is pending' do
            before do
              user.establishing_in_person_enrollment.update(status: 'pending')
            end

            it 'associates the in person enrollment with the created profile' do
              subject.create_profile_from_applicant_with_password(
                user.password, is_enhanced_ipp:, proofing_components:
              )
              expect(enrollment.reload.profile_id).to eq(profile.id)
            end
          end
        end

        context 'when the USPS enrollment throws an enroll exception' do
          before do
            allow(UspsInPersonProofing::EnrollmentHelper).to receive(
              :schedule_in_person_enrollment,
            ).and_throw('Enrollment Failure')
          end

          it 'does not create a profile' do
            subject.create_profile_from_applicant_with_password(
              user.password, is_enhanced_ipp:, proofing_components:
            )
          rescue
            expect(profile).to be_nil
          end
        end
      end

      context 'when the user does not have an establishing in person enrollment' do
        let(:profile) { subject.profile }

        before do
          allow(UspsInPersonProofing::EnrollmentHelper).to receive(:schedule_in_person_enrollment)
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          subject.user_phone_confirmation = true
          subject.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.with_indifferent_access
        end

        it 'does not create an USPS enrollment' do
          subject.create_profile_from_applicant_with_password(
            user.password, is_enhanced_ipp:, proofing_components:
          )
          expect(UspsInPersonProofing::EnrollmentHelper).to_not have_received(
            :schedule_in_person_enrollment,
          )
        end

        it 'creates a profile' do
          subject.create_profile_from_applicant_with_password(
            user.password, is_enhanced_ipp:, proofing_components:
          )
          expect(profile).to have_attributes(
            {
              active: true,
              in_person_verification_pending?: false,
              fraud_review_pending?: false,
              gpo_verification_pending_at: nil,
              initiating_service_provider: nil,
            },
          )
        end

        it 'saves the pii to the session' do
          subject.create_profile_from_applicant_with_password(
            user.password, is_enhanced_ipp:, proofing_components:
          )
          expect(Pii::Cacher.new(user, user_session).fetch(profile.id)).to_not be_nil
        end
      end
    end

    context 'with gpo address verification' do
      before do
        subject.address_verification_mechanism = 'gpo'
        subject.vendor_phone_confirmation = false
      end

      it 'sets profile to pending gpo verification' do
        subject.create_profile_from_applicant_with_password(
          user.password, is_enhanced_ipp:, proofing_components:
        )
        profile = subject.profile

        expect(profile.activated_at).to eq nil
        expect(profile.active).to eq false
        expect(profile.deactivation_reason).to eq nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at.present?).to eq true
        expect(profile.initiating_service_provider).to eq nil
        expect(profile.verified_at).to eq nil

        pii_from_session = Pii::Cacher.new(user, user_session).fetch(profile.id)
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
        subject.create_profile_from_applicant_with_password(
          user.password, is_enhanced_ipp:, proofing_components:
        )
        profile = subject.profile

        expect(profile.activated_at).to eq nil
        expect(profile.active).to eq false
        expect(profile.deactivation_reason).to eq nil
        expect(profile.fraud_review_pending?).to eq(false)
        expect(profile.gpo_verification_pending_at.present?).to eq true
        expect(profile.initiating_service_provider).to eq nil
        expect(profile.verified_at).to eq nil

        pii_from_session = Pii::Cacher.new(user, user_session).fetch(profile.id)
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

  describe '#in_person_passports_allowed?' do
    context 'when passports are allowed' do
      before do
        subject.passport_allowed = true
      end

      context 'when in person passports are enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
        end

        it 'returns true' do
          expect(subject.in_person_passports_allowed?).to be(true)
        end
      end

      context 'when in person passports are disabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(false)
        end

        it 'returns false' do
          expect(subject.in_person_passports_allowed?).to be(false)
        end
      end
    end

    context 'when passports are not allowed' do
      before do
        subject.passport_allowed = false
      end

      context 'when in person passports are enabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(true)
        end

        it 'returns false' do
          expect(subject.in_person_passports_allowed?).to be(false)
        end
      end

      context 'when in person passports are disabled' do
        before do
          allow(IdentityConfig.store).to receive(:in_person_passports_enabled).and_return(false)
        end

        it 'returns false' do
          expect(subject.in_person_passports_allowed?).to be(false)
        end
      end
    end
  end
end
