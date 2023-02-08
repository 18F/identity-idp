module InPerson
  class IppLocationsCacherJob < ApplicationJob
    include ArcgisApi

    def perform(post_offices)
      geocoded_post_offices = Geocoder.new.geocode_addresses(
        post_offices, param_map: {
          Address: :address,
          City: :city,
          Region: :state,
          Postal: :zip_code_5,
        }
      ) do |geocoded_address, post_office|
        {
          address: post_office[:address],
          city: post_office[:city],
          state: post_office[:state],
          zip: post_office[:zip_code_5],

          usps_attributes: post_office,
          lonlat: "
            SRID=#{UspsIppCachedLocations::WGS84_SRID};
            POINT(#{geocoded_address['location']['x']} #{geocoded_address['location']['y']})
          ".squish,
        }
      end

      UspsIppCachedLocations.upsert_all(
        geocoded_post_offices,
        unique_by: [:address, :city, :state, :zip],
      )
    end
  end
end
