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
    context 'the token in the cache is more than 7 mins from expiration' do
      it 'checks the cache but does not make a request' do
        Rails.cache.write(usps_auth_token_cache_key, "test token", expires_in: 900)

        stub_request_token

        expect(WebMock).not_to have_requested(:post, "#{root_url}/oauth/authenticate")
      end
    end

    context 'the token in the cache is less than 7 mins from expiration' do
      context 'when using redis as a backing store' do
        before do |ex|
          allow(Rails).to receive(:cache).and_return(
            ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
          )
        end

        it 'requests and sets a new token in the cache' do
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
          )

          subject.perform

          expect(WebMock).to have_requested(:post, "#{root_url}/oauth/authenticate")
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
    end

    context 'auth request throws error' do
      it 'fetches token and logs analytics' do
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
  end
end
