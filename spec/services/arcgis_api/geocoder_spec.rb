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
  end
end
