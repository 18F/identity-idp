require 'rails_helper'

RSpec.describe ArcgisApi::GeocoderFactory do
  subject(:geocoder_factory) { described_class.new }
  context 'mock is enabled' do
    it 'returns a mock geocoder' do
      expect(IdentityConfig.store).to receive(:arcgis_mock_fallback).
        and_return(true)
      expect(geocoder_factory.create).to be_instance_of(ArcgisApi::Mock::Geocoder)
    end
  end

  context 'mock is disabled' do
    it 'returns a geocoder' do
      expect(IdentityConfig.store).to receive(:arcgis_mock_fallback).
        and_return(false)
      expect(geocoder_factory.create).to be_instance_of(ArcgisApi::Geocoder)
    end
  end
end
