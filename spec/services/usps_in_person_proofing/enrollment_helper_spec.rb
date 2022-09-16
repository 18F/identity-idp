require 'rails_helper'

RSpec.describe UspsInPersonProofing::EnrollmentHelper do
  include UspsIppHelper

  let(:usps_mock_fallback) { false }
  let(:user) { build(:user) }
  let(:current_address_matches_id) { false }
  let(:pii) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.
      merge(same_address_as_id: current_address_matches_id).
      transform_keys(&:to_s)
  end
  let(:subject) { described_class }

  before(:each) do
    stub_request_token
    stub_request_enroll
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(usps_mock_fallback)
  end

  describe '#schedule_in_person_enrollment' do
    context 'when in-person mocking is enabled' do
      let(:usps_mock_fallback) { true }
      let!(:enrollment) do
        create(:in_person_enrollment, user: user, status: :establishing, profile: nil)
      end

      it 'uses a mock proofer' do
        expect(UspsInPersonProofing::Mock::Proofer).to receive(:new).and_call_original

        subject.schedule_in_person_enrollment(user, pii)
      end
    end

    context 'an establishing enrollment record exists for the user' do
      let!(:enrollment) do
        create(:in_person_enrollment, user: user, status: :establishing, profile: nil)
      end

      it 'updates the existing enrollment record' do
        expect(user.in_person_enrollments.length).to eq(1)

        subject.schedule_in_person_enrollment(user, pii)
        enrollment.reload

        expect(enrollment.current_address_matches_id).to eq(current_address_matches_id)
      end

      it 'creates usps enrollment' do
        proofer = UspsInPersonProofing::Mock::Proofer.new
        mock = double

        expect(UspsInPersonProofing::Proofer).to receive(:new).and_return(mock)
        expect(mock).to receive(:request_enroll) do |applicant|
          expect(applicant.first_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:first_name])
          expect(applicant.last_name).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:last_name])
          expect(applicant.address).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:address1])
          expect(applicant.city).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:city])
          expect(applicant.state).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:state])
          expect(applicant.zip_code).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:zipcode])
          expect(applicant.email).to eq('no-reply@login.gov')
          expect(applicant.unique_id).to eq(enrollment.unique_id)

          proofer.request_enroll(applicant)
        end

        subject.schedule_in_person_enrollment(user, pii)
      end

      context 'when fields contain diacritics, extra spaces, or other unsupported characters' do
        let(:first_name) { 'Léa‒Anne ' }
        let(:last_name) { ' P_érez‑Rodríguez-O’   Daly7' }
        let(:address1) { '!12234 Gaëtan Blvd' }
        let(:address2) { ' Apt. ＃4234' }
        let(:pii) do
          Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.
            merge(
              first_name: first_name,
              last_name: last_name,
              address1: address1,
              address2: address2,
            ).transform_keys(&:to_s)
        end
        it 'trims, transliterates, and filters the first name, last name, and address' do
          proofer = UspsInPersonProofing::Mock::Proofer.new
          mock = double

          expect(UspsInPersonProofing::Proofer).to receive(:new).and_return(mock)
          expect(mock).to receive(:request_enroll) do |applicant|
            expect(applicant.first_name).to eq('Lea-Anne')
            expect(applicant.last_name).to eq("Perez-Rodriguez-O' Daly")
            expect(applicant.address).to eq('12234 Gaetan Blvd Apt. #4234')
            expect(applicant.city).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:city])
            expect(applicant.state).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:state])
            expect(applicant.zip_code).to eq(Idp::Constants::MOCK_IDV_APPLICANT[:zipcode])
            expect(applicant.email).to eq('no-reply@login.gov')
            expect(applicant.unique_id).to eq(enrollment.unique_id)

            proofer.request_enroll(applicant)
          end

          subject.schedule_in_person_enrollment(user, pii)
        end
      end

      context 'when the enrollment does not have a unique ID' do
        it 'uses the deprecated InPersonEnrollment#usps_unique_id value to create the enrollment' do
          enrollment.update(unique_id: nil)
          proofer = UspsInPersonProofing::Mock::Proofer.new
          mock = double

          expect(UspsInPersonProofing::Proofer).to receive(:new).and_return(mock)
          expect(mock).to receive(:request_enroll) do |applicant|
            expect(applicant.unique_id).to eq(enrollment.usps_unique_id)

            proofer.request_enroll(applicant)
          end

          subject.schedule_in_person_enrollment(user, pii)
        end
      end

      it 'sets enrollment status to pending and sets established at date and unique id' do
        subject.schedule_in_person_enrollment(user, pii)

        expect(user.in_person_enrollments.first.status).to eq('pending')
        expect(user.in_person_enrollments.first.enrollment_established_at).to_not be_nil
        expect(user.in_person_enrollments.first.unique_id).to_not be_nil
      end

      it 'sends verification emails' do
        mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)
        user.email_addresses.each do |email_address|
          expect(UserMailer).to receive(:in_person_ready_to_verify).
            with(
              user,
              email_address,
              enrollment: instance_of(InPersonEnrollment),
              first_name: Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE[:first_name],
            ).
            and_return(mailer)
        end

        subject.schedule_in_person_enrollment(user, pii)
      end
    end
  end
end
