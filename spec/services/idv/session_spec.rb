require 'rails_helper'

describe Idv::Session do
  let(:user) { create(:user, :with_pending_profile) }
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
        subject.address_verification_mechanism = :phone
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

      context 'when the user is proofing in-person' do
        before do
          subject.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(
            same_address_as_id: true,
          ).with_indifferent_access
          expect(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        end

        it 'creates a USPS enrollment' do
          proofer = UspsInPersonProofing::Mock::Proofer.new
          mock = double

          expect(UspsInPersonProofing::Mock::Proofer).to receive(:new).and_return(mock)
          expect(mock).to receive(:request_enroll) do |applicant|
            expect(applicant.first_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:first_name])
            expect(applicant.last_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:last_name])
            expect(applicant.address).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:address1])
            expect(applicant.city).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:city])
            expect(applicant.state).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:state])
            expect(applicant.zip_code).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:zipcode])
            expect(applicant.email).to eq('no-reply@login.gov')
            expect(applicant.unique_id).to be_a(String)

            proofer.request_enroll(applicant)
          end

          subject.complete_session
        end

        it 'does not complete the profile if the user has completed OTP phone confirmation' do
          subject.user_phone_confirmation = true

          subject.complete_session

          expect(subject).not_to have_received(:complete_profile)
        end
      end
    end

    context 'without a confirmed phone number' do
      before do
        subject.address_verification_mechanism = :phone
        subject.vendor_phone_confirmation = false
      end

      it 'does not complete the user profile' do
        allow(subject).to receive(:complete_profile)
        subject.complete_session
        expect(subject).not_to have_received(:complete_profile)
      end

      context 'when the user is proofing in-person' do
        before do
          subject.applicant = Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.merge(
            same_address_as_id: true,
          ).with_indifferent_access
          expect(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
          ProofingComponent.create(user: user, document_check: Idp::Constants::Vendors::USPS)
        end

        it 'creates a USPS enrollment' do
          proofer = UspsInPersonProofing::Mock::Proofer.new
          mock = double

          expect(UspsInPersonProofing::Mock::Proofer).to receive(:new).and_return(mock)
          expect(mock).to receive(:request_enroll) do |applicant|
            expect(applicant.first_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:first_name])
            expect(applicant.last_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:last_name])
            expect(applicant.address).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:address1])
            expect(applicant.city).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:city])
            expect(applicant.state).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:state])
            expect(applicant.zip_code).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:zipcode])
            expect(applicant.email).to eq('no-reply@login.gov')
            expect(applicant.unique_id).to be_a(String)

            proofer.request_enroll(applicant)
          end

          subject.complete_session
        end
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
