require 'rails_helper'

RSpec.describe ArcgisApi::Geocoder do
  include ArcgisApiHelper

  let(:subject) { ArcgisApi::Geocoder.new }

  describe '#suggest' do
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
end
