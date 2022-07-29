require 'rails_helper'

describe Idv::Session do
  let(:user) { create(:user) }
  let(:user_session) { {} }

  subject {
    Idv::Session.new(user_session: user_session, current_user: user, service_provider: nil)
  }

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

  describe '#complete_session' do
    context 'with phone verifed by vendor' do
      before do
        subject.address_verification_mechanism = 'phone'
        subject.vendor_phone_confirmation = true
        allow(subject).to receive(:complete_profile)
      end

      it 'completes the profile if the user has completed OTP phone confirmation' do
        subject.user_phone_confirmation = true
        subject.complete_session

        expect(subject).to have_received(:complete_profile)
      end

      it 'does not complete the profile if the user has not completed OTP phone confirmation' do
        subject.user_phone_confirmation = nil
        subject.complete_session

        expect(subject).not_to have_received(:complete_profile)
      end

      context 'with pending in person enrollment' do
        let(:selected_location_details) { { name: 'Example' } }

        before do
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
          allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          subject.user_phone_confirmation = true
          subject.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(
            same_address_as_id: true,
            selected_location_details: selected_location_details,
          ).with_indifferent_access
          subject.create_profile_from_applicant_with_password(user.password)
        end

        it 'sets profile to pending in person verification' do
          subject.complete_session

          expect(subject).not_to have_received(:complete_profile)
          expect(subject.profile.deactivation_reason).to eq('in_person_verification_pending')
        end

        it 'creates a USPS enrollment' do
          enrollment_helper = instance_double(UspsInPersonProofing::EnrollmentHelper)
          allow(UspsInPersonProofing::EnrollmentHelper).to receive(:new).
            and_return(enrollment_helper)
          expect(enrollment_helper).to receive(:schedule_in_person_enrollment).with(
            user,
            kind_of(Profile),
            subject.applicant.transform_keys(&:to_s),
            selected_location_details,
          )

          subject.complete_session
        end
      end
    end

    context 'with gpo address verification' do
      before do
        subject.address_verification_mechanism = 'gpo'
        subject.vendor_phone_confirmation = false
        allow(subject).to receive(:complete_profile)
      end

      it 'sets profile to pending gpo verification' do
        subject.applicant = {}
        subject.create_profile_from_applicant_with_password(user.password)
        subject.complete_session

        expect(subject).not_to have_received(:complete_profile)
        expect(subject.profile.deactivation_reason).to eq('gpo_verification_pending')
      end
    end

    context 'without a confirmed phone number' do
      before do
        subject.address_verification_mechanism = 'phone'
        subject.vendor_phone_confirmation = false
      end

      it 'does not complete the user profile' do
        allow(subject).to receive(:complete_profile)
        subject.complete_session
        expect(subject).not_to have_received(:complete_profile)
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
