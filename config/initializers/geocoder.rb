# For some reason the test result class does not impelement the `language=`
# method. This patches an empty method onto it to prevent NoMethodErrors in
# the tests
module Geocoder
  module Result
    class Test
      def language=(_locale); end
    end
  end
end

GEO_DATA_FILEPATH = Rails.root.join(IdentityConfig.store.geo_data_file_path).freeze

if Rails.env.production? && File.exist?(GEO_DATA_FILEPATH)
  Geocoder.configure(
    ip_lookup: :geoip2,
    geoip2: {
      file: GEO_DATA_FILEPATH,
    },
  )
  Geocoder.search('1.2.3.4') # the datasource is lazily loaded, make sure it eager loads
else
  Geocoder.configure(ip_lookup: :test)
  Geocoder::Lookup::Test.set_default_stub(
    [
      { 'city' => '', 'country' => 'United States', 'state_code' => '' },
    ],
  )
end
