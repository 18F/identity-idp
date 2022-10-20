require 'rails_helper'

RSpec.describe ArcgisApi::Geocoder do
  include ArcgisApiHelper

  let(:subject) { ArcgisApi::Geocoder.new }

  describe '#suggest' do
    it 'returns suggestions' do
      stub_request_suggestions

      suggestions = subject.suggest('100 Main')

      expect(suggestions[0][:magicKey]).to be_present
      expect(suggestions[0][:text]).to be_present
    end
  end
end
