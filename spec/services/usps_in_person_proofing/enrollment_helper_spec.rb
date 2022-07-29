require 'rails_helper'

RSpec.describe UspsInPersonProofing::EnrollmentHelper do
  let(:user) { build(:user) }
  let(:profile) { build(:profile, user: user) }
  let(:current_address_matches_id) { false }
  let(:pii) do
    Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE.
      merge(same_address_as_id: current_address_matches_id).
      transform_keys(&:to_s)
  end
  let(:subject) { described_class.new }

  describe '#save_in_person_enrollment' do
    it 'creates an enrollment record' do
      subject.save_in_person_enrollment(user, profile, pii)

      enrollment = user.in_person_enrollments.first
      expect(enrollment.profile).to eq(profile)
      expect(enrollment.current_address_matches_id).to eq(current_address_matches_id)
      expect(enrollment.selected_location_details).to be_nil
    end

    it 'creates usps enrollment' do
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

      subject.save_in_person_enrollment(user, profile, pii)
    end

    it 'sets enrollment status to pending and sets enrollment established at date' do
      subject.save_in_person_enrollment(user, profile, pii)

      expect(user.in_person_enrollments.first.status).to eq('pending')
      expect(user.in_person_enrollments.first.enrollment_established_at).to_not be_nil
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

      subject.save_in_person_enrollment(user, profile, pii)
    end
  end
end
