require 'rails_helper'

def expect_facility_fields_to_be_present(facility)
  expect(facility.address).to be_present
  expect(facility.city).to be_present
  expect(facility.name).to be_present
  expect(facility.saturday_hours).to be_present
  expect(facility.state).to be_present
  expect(facility.sunday_hours).to be_present
  expect(facility.weekday_hours).to be_present
  expect(facility.zip_code_4).to be_present
  expect(facility.zip_code_5).to be_present
end

RSpec.describe UspsInPersonProofing::Proofer do
  include UspsIppHelper

  let(:subject) { UspsInPersonProofing::Proofer.new }
  let(:root_url) { 'http://my.root.url' }
  let(:usps_ipp_sponsor_id) { 1 }
  let(:ipp_assurance_level) { '1.5' }

  before do
    allow(IdentityConfig.store).to receive(:usps_ipp_root_url).and_return(root_url)
  end

  describe '#retrieve_token!' do
    let(:auth_token) do
      '==PZWyMP2ZHGOIeTd17YomIf7XjZUL4G93dboY1pTsuTJN0s9BwMYvOcIS9B3gRvloK2sroi9uFXdXrFuly7=='
    end
    it 'sets token and expiry' do
      expect(Rails.cache).to receive(:write).with(
        UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY,
        an_instance_of(String),
        hash_including(expires_in: an_instance_of(ActiveSupport::Duration)),
      ).twice
      stub_request_token
      subject.retrieve_token!

      expect(subject.token).to eq("Bearer #{auth_token}")
    end

    it 'calls the authenticate endpoint with the expected params' do
      stub_request_token

      username = 'test username'
      password = 'test password'
      client_id = 'test client id'

      expect(IdentityConfig.store).to receive(:usps_ipp_root_url).
        and_return(root_url)
      expect(IdentityConfig.store).to receive(:usps_ipp_username).
        and_return(username)
      expect(IdentityConfig.store).to receive(:usps_ipp_password).
        and_return(password)
      expect(IdentityConfig.store).to receive(:usps_ipp_client_id).
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

    context 'when using redis as a backing store' do
      before do |_ex|
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(
            url: IdentityConfig.store.redis_throttle_url,
            pool: false,
          ),
        )
      end

      it 'reuses the cached auth token on subsequent requests' do
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
        stub_request_token
        stub_request_enroll

        subject.request_enroll(applicant, false)
        subject.request_enroll(applicant, false)
        subject.request_enroll(applicant, false)

        expect(WebMock).to have_requested(:post, %r{/oauth/authenticate}).once
        expect(WebMock).to have_requested(
          :post,
          %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant},
        ).times(3)
      end

      it 'manually sets the expiration' do
        stub_request_token
        subject.retrieve_token!
        ttl = Rails.cache.redis.ttl(UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY)
        expect(ttl).to be > 0
      end
    end
  end

  describe '#token' do
    expires_at = nil
    let(:expires_in) { 15.minutes }

    before do
      stub_request_token
    end

    before(:each) do
      subject.retrieve_token!
      expires_at = Time.zone.now + expires_in
    end

    it 'uses the cached token if it is not expired' do
      next_request_time = expires_at - 5.minutes
      travel_to(next_request_time) do
        subject.token
      end
      expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate").once
    end

    it 'retrieves a new token if the token is expired' do
      travel_to(expires_at) do
        subject.token
      end
      expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate").twice
    end

    it 'retrieves a new token if the token is about to expire' do
      almost_expired_at = expires_at - 50.seconds
      travel_to(almost_expired_at) do
        subject.token
      end
      expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate").twice
    end
  end

  describe '#request_facilities' do
    let(:location) do
      double(
        'Location',
        address: Faker::Address.street_address,
        city: Faker::Address.city,
        state: Faker::Address.state_abbr,
        zip_code: Faker::Address.zip_code,
      )
    end
    let(:request_url) { "#{root_url}/ivs-ippaas-api/IPPRest/resources/rest/getIppFacilityList" }
    let(:is_enhanced_ipp) { false }

    before do
      stub_request_token
      allow(IdentityConfig.store).to receive(:usps_ipp_sponsor_id).and_return(usps_ipp_sponsor_id)
    end

    it 'uses the sponsor id set in the environment config' do
      stub_request_facilities
      subject.request_facilities(location, is_enhanced_ipp)

      expect(WebMock).to have_requested(:post, request_url).
        with(
          body: hash_including(
            {
              sponsorID: usps_ipp_sponsor_id,
            },
          ),
        )
    end

    it 'returns facilities' do
      stub_request_facilities
      facilities = subject.request_facilities(location, is_enhanced_ipp)

      expect_facility_fields_to_be_present(facilities[0])
    end

    it 'returns facilities sorted by ascending distance' do
      stub_request_facilities_with_unordered_distance
      facilities = subject.request_facilities(location, is_enhanced_ipp)

      expect(facilities.count).to be > 1
      facilities.each_cons(2) do |facility_a, facility_b|
        expect(facility_a.distance).to be <= facility_b.distance
      end
    end

    it 'does not return duplicates' do
      stub_request_facilities_with_duplicates
      facilities = subject.request_facilities(location, is_enhanced_ipp)

      expect(facilities.length).to eq(9)
      expect(
        facilities.count do |post_office|
          post_office.address == '3775 INDUSTRIAL BLVD'
        end,
      ).to eq(1)
    end

    context 'when the user is going through enhanced ipp' do
      let(:usps_eipp_sponsor_id) { '314159265359' }
      let(:is_enhanced_ipp) { true }
      before do
        allow(IdentityConfig.store).to receive(:usps_eipp_sponsor_id).
          and_return(usps_eipp_sponsor_id)
      end
      it 'uses the usps_eipp_sponsor_id in calls to the USPS API' do
        stub_request_enhanced_ipp_facilities
        subject.request_facilities(location, is_enhanced_ipp)

        expect(WebMock).to have_requested(:post, request_url).
          with(
            body: hash_including(
              {
                sponsorID: usps_eipp_sponsor_id.to_i,
              },
            ),
          )
      end
    end

    context 'when the auth token is expired' do
      expires_at = nil
      let(:expires_in) { 15.minutes }

      before do
        stub_request_facilities
      end

      before(:each) do
        subject.retrieve_token!
        expires_at = Time.zone.now + expires_in
      end

      it 'refreshes the auth token before making the request' do
        facilities = nil
        travel_to(expires_at) do
          facilities = subject.request_facilities(location, is_enhanced_ipp)
        end

        expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate").twice
        expect(facilities.length).to eq(10)
        expect_facility_fields_to_be_present(facilities[0])
      end
    end

    context 'when there is a 4xx error for a bad sponsor id' do
      it 'raises a Faraday::BadRequestError' do
        stub_request_facilities_with_sponsor_error
        expect { subject.request_facilities(location, is_enhanced_ipp) }.to raise_error do |error|
          expect(error).to be_an_instance_of(Faraday::BadRequestError)
          expect(error.response).to include(
            body: include(
              'responseMessage' => 'Sponsor for sponsorID 5 not found',
            ),
          )
        end
      end
    end
  end

  describe '#request_enroll' do
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
    let(:is_enhanced_ipp) { false }
    let(:request_url) { "#{root_url}/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant" }
    let(:usps_ipp_sponsor_id) { '42' }
    let(:ipp_assurance_level) { '1.5' }

    before do
      stub_request_token
      allow(IdentityConfig.store).to receive(:usps_ipp_sponsor_id).
        and_return(usps_ipp_sponsor_id)
    end

    context 'when the USPS optInIPPApplicant response is a success status' do
      context 'when the enrollment is ID-IPP' do
        let(:is_enhanced_ipp) { false }

        before do
          stub_request_enroll
          @response = subject.request_enroll(applicant, is_enhanced_ipp)
        end

        it 'sends a request to the USPS optInIPPApplicant endpoint' do
          expect(WebMock).to have_requested(
            :post,
            "#{root_url}/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant",
          ).with(
            body: {
              uniqueID: applicant.unique_id,
              firstName: applicant.first_name,
              lastName: applicant.last_name,
              streetAddress: applicant.address,
              city: applicant.city,
              state: applicant.state,
              zipCode: applicant.zip_code,
              emailAddress: applicant.email,
              sponsorID: usps_ipp_sponsor_id.to_i,
              IPPAssuranceLevel: ipp_assurance_level,
            },
          )
        end

        it 'returns the enrollment response' do
          expect(@response.enrollment_code).to be_present
          expect(@response.response_message).to be_present
        end
      end

      context 'when the enrollment is enhanced ipp' do
        let(:usps_eipp_sponsor_id) { '314159265359' }
        let(:ipp_assurance_level) { '2.0' }
        let(:is_enhanced_ipp) { true }

        before do
          allow(IdentityConfig.store).to receive(:usps_eipp_sponsor_id).
            and_return(usps_eipp_sponsor_id)
          stub_request_enroll
          @response = subject.request_enroll(applicant, is_enhanced_ipp)
        end

        it 'sends a request to the USPS optInIPPApplicant endpoint' do
          expect(WebMock).to have_requested(
            :post,
            "#{root_url}/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant",
          ).with(
            body: {
              uniqueID: applicant.unique_id,
              firstName: applicant.first_name,
              lastName: applicant.last_name,
              streetAddress: applicant.address,
              city: applicant.city,
              state: applicant.state,
              zipCode: applicant.zip_code,
              emailAddress: applicant.email,
              sponsorID: usps_eipp_sponsor_id.to_i,
              IPPAssuranceLevel: ipp_assurance_level,
            },
          )
        end

        it 'returns the enrollment response' do
          expect(@response.enrollment_code).to be_present
          expect(@response.response_message).to be_present
        end
      end

      context 'when the auth token is expired' do
        let(:expires_in) { 15.minutes }
        let(:expires_at) { Time.zone.now + expires_in }

        before do
          stub_request_enroll
          subject.retrieve_token!
          subject.token
          travel_to(expires_at) do
            @response = subject.request_enroll(applicant, false)
          end
        end

        it 'refreshes the auth token' do
          expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate").twice
        end

        it 'returns the enrollment response' do
          expect(@response.enrollment_code).to be_present
          expect(@response.response_message).to be_present
        end
      end
    end

    context 'when the USPS optInIPPApplicant response is a failure status' do
      context 'when the response has a status code of 400' do
        before do
          stub_request_enroll_bad_request_response
        end

        it 'throws a Faraday::BadRequestError' do
          expect { subject.request_enroll(applicant, is_enhanced_ipp) }.to raise_error(
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
      end

      context 'when the response has a status code of 500' do
        before do
          @mock = stub_request_enroll_internal_server_error_response

          subject.request_enroll(applicant, is_enhanced_ipp)
        rescue StandardError => err
          @response = err
        end

        it 'retries the USPS optInIPPApplicant request 4 times' do
          expect(@mock).to have_been_made.times(4)
        end

        it 'throws a Faraday::ServerError' do
          expect(@response).to be_an_instance_of(Faraday::ServerError).and(
            having_attributes(
              response: include(
                body: include(
                  'responseMessage' => 'An internal error occurred processing the request',
                ),
              ),
            ),
          )
        end
      end
    end

    context 'when the USPS server has intermittant errors' do
      before do
        @mock = stub_request_enroll_server_down_time_response
        @response = subject.request_enroll(applicant, is_enhanced_ipp)
      end

      it 'retries the USPS optInIPPApplicant request' do
        expect(@mock).to have_been_made.times(3)
      end

      it 'returns the enrollment response' do
        expect(@response.enrollment_code).to be_present
        expect(@response.response_message).to be_present
      end
    end
  end

  describe '#request_proofing_results' do
    let(:applicant) do
      double(
        'applicant',
        unique_id: '123456789',
        enrollment_code: '123456789',
        sponsor_id: '314159265359',
      )
    end

    before do
      stub_request_token
    end

    context 'when the user is going through enhanced ipp' do
      let(:request_body) do
        {
          sponsorID: applicant.sponsor_id.to_i,
          uniqueID: applicant.unique_id,
          enrollmentCode: applicant.enrollment_code,
        }
      end
      let(:faraday_response) { double('faraday_response', body: 'blah blah') }
      let(:faraday) { Faraday.new }
      before do
        allow(Faraday).to receive(:new).and_return(faraday)
        allow(Rails.cache).to receive(:read).and_return('some fake token')
      end
      it 'sends the correct information in the request body' do
        expect(faraday).to receive(:post).with(
          anything, request_body,
          anything
        ).and_return(faraday_response)
        subject.request_proofing_results(applicant)
      end
    end

    it 'returns failed enrollment information' do
      stub_request_failed_proofing_results

      proofing_results = subject.request_proofing_results(applicant)
      expect(proofing_results['status']).to eq 'In-person failed'
      expect(proofing_results['fraudSuspected']).to eq false
    end

    it 'returns passed enrollment information' do
      stub_request_passed_proofing_results

      proofing_results = subject.request_proofing_results(applicant)
      expect(proofing_results['status']).to eq 'In-person passed'
      expect(proofing_results['fraudSuspected']).to eq false
    end

    it 'returns in-progress enrollment information' do
      stub_request_in_progress_proofing_results

      expect do
        subject.request_proofing_results(applicant)
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

    context 'when the auth token is expired' do
      expires_at = nil
      let(:expires_in) { 15.minutes }

      before do
        stub_request_passed_proofing_results
      end

      before(:each) do
        subject.retrieve_token!
        expires_at = Time.zone.now + expires_in
      end

      it 'refreshes the auth token before making the request' do
        subject.token
        proofing_results = nil
        travel_to(expires_at) do
          proofing_results = subject.request_proofing_results(applicant)
        end

        expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate").twice
        expect(proofing_results['status']).to eq 'In-person passed'
        expect(proofing_results['fraudSuspected']).to eq false
      end
    end
  end
end
