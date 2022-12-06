require 'rails_helper'

RSpec.describe ArcgisApi::Geocoder do
  include ArcgisApiHelper

  let(:subject) { ArcgisApi::Geocoder.new }

  describe '#suggest' do
    before(:each) do
      stub_generate_token_response
    end

    it 'returns suggestions' do
      stub_request_suggestions

      suggestions = subject.suggest('100 Main')

      expect(suggestions.first.magic_key).to be_present
      expect(suggestions.first.text).to be_present
    end

    it 'returns an error response body but with Status coded as 200' do
      stub_request_suggestions_error

      expect { subject.suggest('100 Main') }.to raise_error do |error|
        expect(error).to be_instance_of(Faraday::ClientError)
        expect(error.message).to eq('received error code 400')
        expect(error.response).to be_kind_of(Hash)
      end
    end

    it 'returns an error with Status coded as 4** in HTML' do
      stub_request_suggestions_error_html

      expect { subject.suggest('100 Main') }.to raise_error(
        an_instance_of(Faraday::BadRequestError),
      )
    end
  end

  describe '#find_address_candidates' do
    before(:each) do
      stub_generate_token_response
    end

    it 'returns candidates from magic_key' do
      stub_request_candidates_response

      suggestions = subject.find_address_candidates('abc123')

      expect(suggestions.first.as_json).to eq(
        {
          'address' => '100 Main Ave, La Grande, Oregon, 97850',
          'location' => { 'longitude' => -118.10754025791812, 'latitude' => 45.328271485226445 },
          'street_address' => '100 Main Ave',
          'city' => 'La Grande',
          'state' => 'OR',
          'zip_code' => '97850',
        },
      )
    end

    # https://developers.arcgis.com/rest/geocode/api-reference/geocoding-service-output.htm#ESRI_SECTION3_619341BEAA3A4F488FC66FAE8E479563
    it 'handles no results' do
      stub_request_candidates_empty_response

      suggestions = subject.find_address_candidates('abc123')

      expect(suggestions).to be_empty
    end

    it 'returns an error response body but with Status coded as 200' do
      stub_request_candidates_error

      expect { subject.find_address_candidates('abc123') }.to raise_error do |error|
        expect(error).to be_instance_of(Faraday::ClientError)
        expect(error.message).to eq('received error code 400')
        expect(error.response).to be_kind_of(Hash)
      end
    end
  end

  describe '#retrieve_token!' do
    it 'sets token and token_expires_at' do
      stub_generate_token_response
      subject.retrieve_token!

      expect(subject.token).to be_present
    end

    it 'calls the endpoint with the expected params' do
      stub_generate_token_response
      username = 'test username'
      password = 'test password'

      allow(IdentityConfig.store).to receive(:arcgis_api_username).
        and_return(username)
      allow(IdentityConfig.store).to receive(:arcgis_api_password).
        and_return(password)

      subject.retrieve_token!

      expect(WebMock).to have_requested(:post, %r{/generateToken}).
        with(
          body: 'username=test+username&password=test+password&referer=www.example.com&f=json',
        )
    end

    it 'reuses the cached token on subsequent requests' do
      stub_generate_token_response
      stub_request_suggestions
      stub_request_suggestions
      stub_request_suggestions

      subject.suggest('1')
      subject.suggest('100')
      subject.suggest('100 Main')

      expect(WebMock).to have_requested(:post, %r{/generateToken}).once
      expect(WebMock).to have_requested(:get, %r{/suggest}).times(3)
    end

    it 'implicitly refreshes the token when expired' do
      root_url = 'http://my.root.url'
      allow(IdentityConfig.store).to receive(:arcgis_api_root_url).
        and_return(root_url)

      stub_generate_token_response(expires_at: 1.hour.from_now.to_i * 1000, token: 'token1')
      stub_request_suggestions
      subject.suggest('100 Main')

      travel 2.hours

      stub_generate_token_response(token: 'token2')
      stub_request_suggestions
      subject.suggest('100 Main')

      expect(WebMock).to have_requested(:post, %r{/generateToken}).twice
      expect(WebMock).to have_requested(:get, %r{/suggest}).
        with(headers: { 'Authorization' => 'Bearer token1' }).once
      expect(WebMock).to have_requested(:get, %r{/suggest}).
        with(headers: { 'Authorization' => 'Bearer token1' }).once
    end

    it 'reuses the cached token across instances' do
      stub_generate_token_response(token: 'token1')
      stub_request_suggestions
      stub_request_suggestions

      client1 = ArcgisApi::Geocoder.new
      client2 = ArcgisApi::Geocoder.new

      client1.suggest('1')
      client2.suggest('100')

      expect(WebMock).to have_requested(:get, %r{/suggest}).
        with(headers: { 'Authorization' => 'Bearer token1' }).twice
    end

    context 'when using redis as a backing store' do
      before do |ex|
        allow(Rails).to receive(:cache).and_return(
          ActiveSupport::Cache::RedisCacheStore.new(url: IdentityConfig.store.redis_throttle_url),
        )
      end

      it 'manually sets the expiration if the cache store is redis' do
        stub_generate_token_response
        subject.retrieve_token!
        ttl = Rails.cache.redis.ttl(ArcgisApi::Geocoder::API_TOKEN_CACHE_KEY)
        expect(ttl).to be > 0
      end
    end
  end
end
