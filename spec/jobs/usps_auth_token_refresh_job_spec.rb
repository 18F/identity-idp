require 'rails_helper'

RSpec.describe UspsAuthTokenRefreshJob, type: :job do
  include UspsIppHelper

  let(:subject) { described_class.new }
  let(:root_url) { 'http://my.root.url' }
  let(:analytics) { instance_double(Analytics) }
  let(:usps_auth_token_cache_key) { UspsInPersonProofing::Proofer::AUTH_TOKEN_CACHE_KEY }

  before do
    allow(IdentityConfig.store).to receive(:usps_ipp_root_url).and_return(root_url)

    allow(Analytics).to receive(:new).
      with(
        user: an_instance_of(AnonymousUser),
        request: nil,
        session: {},
        sp: nil,
      ).and_return(analytics)
  end

  describe 'usps auth token refresh job' do
    context 'when using redis as a backing store' do
      before do |ex|
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
        )
      end

      it 'requests and sets a new token in the cache' do
        # rubocop:disable Layout/LineLength
        new_token_value = '==PZWyMP2ZHGOIeTd17YomIf7XjZUL4G93dboY1pTsuTJN0s9BwMYvOcIS9B3gRvloK2sroi9uFXdXrFuly7=='
        # rubocop:enable Layout/LineLength
        stub_request_token

        expect(analytics).to receive(
          :idv_usps_auth_token_refresh_job_started,
        ).once
        expect(analytics).to receive(
          :idv_usps_auth_token_refresh_job_completed,
        ).once

        expect(Rails.cache).to receive(:write).with(
          usps_auth_token_cache_key,
          an_instance_of(String),
          hash_including(expires_in: an_instance_of(ActiveSupport::Duration)),
        ).and_call_original

        subject.perform

        expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate")
        expect(Rails.cache.fetch(usps_auth_token_cache_key)).to eq("Bearer #{new_token_value}")
      end

      it 'manually sets the expiration' do
        allow(analytics).to receive(:idv_usps_auth_token_refresh_job_started)
        allow(analytics).to receive(:idv_usps_auth_token_refresh_job_completed)

        stub_request_token
        subject.perform

        ttl = Rails.cache.redis.ttl(usps_auth_token_cache_key)
        expect(ttl).to be > 0
      end
    end

    context 'auth request throws error' do
      it 'still logs analytics' do
        stub_error_request_token

        expect(analytics).to receive(
          :idv_usps_auth_token_refresh_job_started,
        ).once
        expect(analytics).to receive(
          :idv_usps_auth_token_refresh_job_completed,
        ).once

        expect do
          subject.perform
        end.to raise_error
      end
    end

    context 'auth request throws network error' do
      [Faraday::TimeoutError, Faraday::ConnectionFailed].each do |err_class|
        it "logs analytics without raising the #{err_class.name}" do
          stub_network_error_request_token(
            err_class.new('test error'),
          )

          expect(analytics).to receive(
            :idv_usps_auth_token_refresh_job_started,
          ).once
          expect(analytics).to receive(
            :idv_usps_auth_token_refresh_job_network_error,
          ).with(
            exception_class: err_class.name,
            exception_message: 'test error',
          ).once
          expect(analytics).to receive(
            :idv_usps_auth_token_refresh_job_completed,
          ).once

          subject.perform
        end
      end
    end
  end
end
