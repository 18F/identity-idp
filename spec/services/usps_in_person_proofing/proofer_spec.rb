require 'rails_helper'

RSpec.describe UspsInPersonProofing::Proofer do
  include UspsIppHelper

  let(:subject) { UspsInPersonProofing::Proofer.new }

  describe '#retrieve_token!' do
    it 'sets token and token_expires_at' do
      stub_request_token
      subject.retrieve_token!

      expect(subject.token).to be_present
      expect(subject.token_expires_at).to be_present
    end
  end

  def check_facility(facility)
    expect(facility.address).to be_present
    expect(facility.city).to be_present
    expect(facility.distance).to be_present
    expect(facility.name).to be_present
    expect(facility.phone).to be_present
    expect(facility.saturday_hours).to be_present
    expect(facility.state).to be_present
    expect(facility.sunday_hours).to be_present
    expect(facility.weekday_hours).to be_present
    expect(facility.zip_code_4).to be_present
    expect(facility.zip_code_5).to be_present
  end

  describe '#request_facilities' do
    it 'returns facilities' do
      stub_request_token
      stub_request_facilities
      location = double(
        'Location',
        address: Faker::Address.street_address,
        city: Faker::Address.city,
        state: Faker::Address.state_abbr,
        zip_code: Faker::Address.zip_code,
      )

      facilities = subject.request_facilities(location)

      check_facility(facilities[0])
    end
  end

  describe '#request_pilot_facilities' do
    it 'returns facilities' do
      facilities = subject.request_pilot_facilities
      expect(facilities.length).to eq(7)

      check_facility(facilities[0])
    end
  end

  describe '#request_enroll' do
    it 'returns enrollment information' do
      stub_request_token
      stub_request_enroll
      applicant = double(
        'applicant',
        address: Faker::Address.street_address,
        city: Faker::Address.city,
        state: Faker::Address.state_abbr,
        zip_code: Faker::Address.zip_code,
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        email: Faker::Internet.safe_email,
        unique_id: '123456789',
      )

      enrollment = subject.request_enroll(applicant)
      expect(enrollment['enrollmentCode']).to be_present
      expect(enrollment['responseMessage']).to be_present
    end
  end

  describe '#request_proofing_results' do
    it 'returns failed enrollment information' do
      stub_request_token
      stub_request_failed_proofing_results

      applicant = double(
        'applicant',
        unique_id: '123456789',
        enrollment_code: '123456789',
      )

      proofing_results = subject.request_proofing_results(
        applicant.unique_id,
        applicant.enrollment_code,
      )
      expect(proofing_results['status']).to eq 'In-person failed'
      expect(proofing_results['fraudSuspected']).to eq false
    end

    it 'returns passed enrollment information' do
      stub_request_token
      stub_request_passed_proofing_results

      applicant = double(
        'applicant',
        unique_id: '123456789',
        enrollment_code: '123456789',
      )

      proofing_results = subject.request_proofing_results(
        applicant.unique_id,
        applicant.enrollment_code,
      )
      expect(proofing_results['status']).to eq 'In-person passed'
      expect(proofing_results['fraudSuspected']).to eq false
    end

    it 'returns in-progress enrollment information' do
      stub_request_token
      stub_request_in_progress_proofing_results

      applicant = double(
        'applicant',
        unique_id: '123456789',
        enrollment_code: '123456789',
      )

      expect do
        subject.request_proofing_results(
          applicant.unique_id,
          applicant.enrollment_code,
        )
      end.to raise_error(
        an_instance_of(Faraday::BadRequestError).
        and(having_attributes(
          response: include(
            body: include(
              'responseMessage' => 'Customer has not been to a post office to complete IPP',
            ),
          ),
        )),
      )
    end
  end

  describe '#request_enrollment_code' do
    it 'returns enrollment information' do
      stub_request_token
      stub_request_enrollment_code
      applicant = double(
        'applicant',
        unique_id: '123456789',
      )

      enrollment = subject.request_enrollment_code(applicant)
      expect(enrollment['enrollmentCode']).to be_present
      expect(enrollment['responseMessage']).to be_present
    end
  end
end
