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
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
    let(:cache) { Rails.cache }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear
    end
  
    it 'sets token and token_expires_at' do
      stub_generate_token_response
      subject.retrieve_token!

      expect(subject.token).to be_present
    end

    it 'calls the endpoint with the expected params' do
      stub_generate_token_response
      root_url = 'http://my.root.url'
      username = 'test username'
      password = 'test password'

      allow(IdentityConfig.store).to receive(:arcgis_api_root_url).
        and_return(root_url)
      allow(IdentityConfig.store).to receive(:arcgis_api_username).
        and_return(username)
      allow(IdentityConfig.store).to receive(:arcgis_api_password).
        and_return(password)

      subject.retrieve_token!

      expect(WebMock).to have_requested(:post, "#{root_url}/portal/sharing/rest/generateToken").
        with(
          body: 'username=test+username&password=test+password&referer=www.example.com&f=json',
          headers: {
            'Accept' => '*/*',
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'User-Agent' => 'Faraday v1.8.0',
          },
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
    end

    it 'implicitly refreshes the token when expired' do
      stub_generate_token_response(1.hour.from_now.to_i)
      stub_request_suggestions
      subject.suggest('100 Main')
      expect(subject.token_valid?).to be(true)

      travel 2.hours
      expect(subject.token_valid?).to be(false)

      stub_generate_token_response
      stub_request_suggestions
      subject.suggest('100 Main')
      expect(subject.token_valid?).to be(true)
    end
  end
end
