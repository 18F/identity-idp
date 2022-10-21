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

      expect { subject.suggest('100 Main') }.to raise_error(
        an_instance_of(Faraday::ClientError),
      )
    end

    it 'returns an error with Status coded as 4** in HTML' do
      stub_request_suggestions_error_html

      expect { subject.suggest('100 Main') }.to raise_error(
        an_instance_of(Faraday::BadRequestError),
      )
    end
  end
end
