module ArcgisApi
  class GeocoderFactory
    def create
      if IdentityConfig.store.arcgis_mock_fallback
        ArcgisApi::Mock::Geocoder.new
      else
        ArcgisApi::Geocoder.new
      end
    end
  end
end
