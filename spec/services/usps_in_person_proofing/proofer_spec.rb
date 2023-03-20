require 'rails_helper'

RSpec.describe UspsInPersonProofing::Proofer do
  include UspsIppHelper

  let(:subject) { UspsInPersonProofing::Proofer.new }
  let(:root_url) { 'http://my.root.url' }
  let(:usps_ipp_sponsor_id) { 1 }

  describe '#retrieve_token!' do
    it 'sets token and token_expires_at' do
      stub_request_token
      subject.retrieve_token!

      expect(subject.token).to be_present
    end

    it 'calls the endpoint with the expected params' do
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
      before do |ex|
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
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

        subject.request_enroll(applicant)
        subject.request_enroll(applicant)
        subject.request_enroll(applicant)

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

  def check_facility(facility)
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

  def set_up_expired_token(cache, redis)
    allow(Rails).to receive(:cache).and_return(
      cache,
    )
    allow(cache).to receive(:redis).and_return(redis)
    allow(redis).to receive(:ttl).and_return(0)

    stub_expired_request_token
  end

  def check_for_token_refresh_and_method_call(cache, redis)
    expect(IdentityConfig.store).to receive(:usps_ipp_root_url).
      and_return(root_url).exactly(3).times
    expect(IdentityConfig.store).to receive(:usps_ipp_sponsor_id).
      and_return(usps_ipp_sponsor_id)

    expect(cache).to receive(:write).with(
      UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY,
      an_instance_of(String),
      hash_including(expires_at: an_instance_of(ActiveSupport::TimeWithZone)),
    ).twice

    expect(redis).to receive(:expireat).with(
      UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY,
      an_instance_of(Integer),
    ).twice

    expect(cache).to receive(:read).with(UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY)
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
    context 'when the token is valid' do
      before do
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
        )
        stub_request_token
      end

      it 'returns facilities' do
        stub_request_facilities
        facilities = subject.request_facilities(location)

        check_facility(facilities[0])
      end

      it 'returns facilities sorted by ascending distance' do
        stub_request_facilities_with_unordered_distance
        facilities = subject.request_facilities(location)

        expect(facilities.count).to be > 1
        facilities.each_cons(2) do |facility_a, facility_b|
          expect(facility_a.distance).to be <= facility_b.distance
        end
      end

      it 'does not return duplicates' do
        stub_request_facilities_with_duplicates
        facilities = subject.request_facilities(location)

        expect(facilities.length).to eq(9)
        expect(
          facilities.count do |post_office|
            post_office.address == '3775 INDUSTRIAL BLVD'
          end,
        ).to eq(1)
      end
    end

    context 'when the token is expired' do
      let(:cache) { double(ActiveSupport::Cache::MemoryStore) }
      let(:redis) { double(Redis) }
      before do
        set_up_expired_token(cache, redis)
        stub_request_token
        stub_request_facilities
      end

      it 'fetches a new token' do
        check_for_token_refresh_and_method_call(cache, redis)

        facilities = subject.request_facilities(location)

        expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate").twice

        expect(facilities.length).to eq(10)
        check_facility(facilities[0])
      end
    end
  end

  describe '#request_enroll' do
    let(:cache) { double(ActiveSupport::Cache::MemoryStore) }
    let(:redis) { double(Redis) }
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
    context 'when the token is valid' do
      before do
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
        )
        stub_request_token
      end
      it 'returns enrollment information' do
        stub_request_enroll

        enrollment = subject.request_enroll(applicant)
        expect(enrollment.enrollment_code).to be_present
        expect(enrollment.response_message).to be_present
      end

      it 'returns 400 error' do
        stub_request_enroll_bad_request_response

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
        stub_request_enroll_internal_server_error_response

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

    context 'when the token is expired' do
      before do
        set_up_expired_token(cache, redis)
        stub_request_enroll_expired_token
        stub_request_enroll
      end

      it 'fetches a new token and retries the attempt' do
        check_for_token_refresh_and_method_call(cache, redis)
        enrollment = subject.request_enroll(applicant)

        expect(enrollment.enrollment_code).to be_present
        expect(enrollment.response_message).to be_present
      end
    end
  end

  describe '#request_proofing_results' do
    let(:applicant) do
      double(
        'applicant',
        unique_id: '123456789',
        enrollment_code: '123456789',
      )
    end
    context 'when the token is valid' do
      before do
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
        )
        stub_request_token
      end
      it 'returns failed enrollment information' do
        stub_request_failed_proofing_results

        proofing_results = subject.request_proofing_results(
          applicant.unique_id,
          applicant.enrollment_code,
        )
        expect(proofing_results['status']).to eq 'In-person failed'
        expect(proofing_results['fraudSuspected']).to eq false
      end

      it 'returns passed enrollment information' do
        stub_request_passed_proofing_results

        proofing_results = subject.request_proofing_results(
          applicant.unique_id,
          applicant.enrollment_code,
        )
        expect(proofing_results['status']).to eq 'In-person passed'
        expect(proofing_results['fraudSuspected']).to eq false
      end

      it 'returns in-progress enrollment information' do
        stub_request_in_progress_proofing_results

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
    context 'when the token is expired' do
      let(:cache) { double(ActiveSupport::Cache::MemoryStore) }
      let(:redis) { double(Redis) }
      before do
        set_up_expired_token(cache, redis)
        stub_request_proofing_results_with_forbidden_error
        stub_request_passed_proofing_results
      end

      it 'fetches a new token and retries the attempt' do
        expect(cache).to receive(:write).with(
          UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY,
          an_instance_of(String),
          hash_including(expires_at: an_instance_of(ActiveSupport::TimeWithZone)),
        ).twice

        expect(redis).to receive(:expireat).with(
          UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY,
          an_instance_of(Integer),
        ).twice

        expect(cache).to receive(:read).with(UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY)

        proofing_results = subject.request_proofing_results(
          applicant.unique_id,
          applicant.enrollment_code,
        )

        expect(proofing_results['status']).to eq 'In-person passed'
        expect(proofing_results['fraudSuspected']).to eq false
      end
    end
  end

  describe '#request_enrollment_code' do
    let(:applicant) do
      double(
        'applicant',
        unique_id: '123456789',
      )
    end
    context 'when the token is valid' do
      before do
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
        )
        stub_request_token
      end

      it 'returns enrollment information' do
        stub_request_enrollment_code

        enrollment = subject.request_enrollment_code(applicant)
        expect(enrollment['enrollmentCode']).to be_present
        expect(enrollment['responseMessage']).to be_present
      end
    end

    context 'when the token is expired' do
      let(:cache) { double(ActiveSupport::Cache::MemoryStore) }
      let(:redis) { double(Redis) }
      before do
        set_up_expired_token(cache, redis)
      end

      it 'fetches a new token and retries the attempt' do
        expect(IdentityConfig.store).to receive(:usps_ipp_sponsor_id).
          and_return(usps_ipp_sponsor_id)

        stub_request_enrollment_code_with_forbidden_error
        stub_request_enrollment_code

        expect(cache).to receive(:write).with(
          UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY,
          an_instance_of(String),
          hash_including(expires_at: an_instance_of(ActiveSupport::TimeWithZone)),
        ).twice

        expect(redis).to receive(:expireat).with(
          UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY,
          an_instance_of(Integer),
        ).twice

        expect(cache).to receive(:read).with(UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY)

        enrollment = subject.request_enrollment_code(applicant)

        expect(enrollment['enrollmentCode']).to be_present
        expect(enrollment['responseMessage']).to be_present
      end
    end
  end
end
