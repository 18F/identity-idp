require 'rails_helper'

RSpec.describe UspsInPersonProofing::Proofer do
  include UspsIppHelper

  let(:subject) { UspsInPersonProofing::Proofer.new }

  describe '#retrieve_token!' do
    let(:applicant) do
      double(
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
    end

    it 'calls the endpoint with the expected params' do
      stub_request_token

      root_url = 'http://my.root.url'
      username = 'test username'
      password = 'test password'
      client_id = 'test client id'

      allow(IdentityConfig.store).to receive(:usps_ipp_root_url).
        and_return(root_url)
      allow(IdentityConfig.store).to receive(:usps_ipp_username).
        and_return(username)
      allow(IdentityConfig.store).to receive(:usps_ipp_password).
        and_return(password)
      allow(IdentityConfig.store).to receive(:usps_ipp_client_id).
        and_return(client_id)

      subject.retrieve_token!

      expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate").
        with(
          body: hash_including(
            {
              'username' => username,
              'password' => password,
              'grant_type' => 'implicit',
              'response_type' => 'token',
              'client_id' => client_id,
              'scope' => 'ivs.ippaas.apis',
            },
          ),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
          },
        )
    end

    it 'caches the token' do
      stub_request_token
      token = subject.retrieve_token!

      expect(subject).not_to receive(:request_token)
      expect(subject.token).to eq(token)
    end

    it 'reuses the cached token on subsequent requests' do
      stub_request_token
      stub_request_enroll
      stub_request_enroll
      stub_request_enroll

      subject.request_enroll(applicant)
      subject.request_enroll(applicant)
      subject.request_enroll(applicant)
      expect(WebMock).to have_requested(:post, %r{/oauth/authenticate}).once
    end

    it 'implicitly refreshes the token when expired' do
      stub_request_token(expires_in: 1.hour.to_i, access_token: 'token1')
      stub_request_enroll
      subject.request_enroll(applicant)

      travel 2.hours

      stub_request_token(access_token: 'token2')
      stub_request_enroll
      subject.request_enroll(applicant)

      expect(WebMock).to have_requested(:post, %r{/oauth/authenticate}).twice
      expect(WebMock).to have_requested(
        :post,
        %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant},
      ).
        with(headers: { 'Authorization' => 'token1' }).once
      expect(WebMock).to have_requested(
        :post,
        %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant},
      ).
        with(headers: { 'Authorization' => 'token2' }).once
    end

    it 'reuses the cached token across instances' do
      stub_request_token(access_token: 'token1')
      stub_request_enroll
      stub_request_enroll

      client2 = UspsInPersonProofing::Proofer.new

      subject.request_enroll(applicant)
      client2.request_enroll(applicant)

      expect(WebMock).to have_requested(
        :post,
        %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant},
      ).
        with(headers: { 'Authorization' => 'token1' }).twice
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
      expect(enrollment.enrollment_code).to be_present
      expect(enrollment.response_message).to be_present
    end

    it 'returns 400 error' do
      stub_request_token
      stub_request_enroll_bad_request_response
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

      expect { subject.request_enroll(applicant) }.to raise_error(
        an_instance_of(Faraday::BadRequestError).
        and(having_attributes(
          response: include(
            body: include(
              'responseMessage' => 'Sponsor for sponsorID 5 not found',
            ),
          ),
        )),
      )
    end

    it 'returns 500 error' do
      stub_request_token
      stub_request_enroll_internal_server_error_response
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

      expect { subject.request_enroll(applicant) }.to raise_error(
        an_instance_of(Faraday::ServerError).
        and(having_attributes(
          response: include(
            body: include(
              'responseMessage' => 'An internal error occurred processing the request',
            ),
          ),
        )),
      )
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
