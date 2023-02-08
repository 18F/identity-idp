module InPerson
  class IppLocationsCacherJob < ApplicationJob
    include ArcgisApi

    def perform(post_offices)
      geocoded_post_offices = geocode_post_offices(post_offices)

      UspsIppCachedLocations.upsert_all(
        geocoded_post_offices.map do |geocoded_post_office|
          {
            address: geocoded_post_office[:address],
            city: geocoded_post_office[:city],
            state: geocoded_post_office[:state],
            zip: geocoded_post_office[:zip_code_5],

            usps_attributes: geocoded_post_office,
            lonlat: geocoded_post_office[:lonlat],
          }
        end,
        unique_by: [:address, :city, :state, :zip],
      )
    end

    # TODO: implement batch geocoder
    def geocode_post_offices(post_offices)
      post_offices.map do |post_office|
        geocoded_post_office = Geocoder.new.find_address_candidates(
          Address: post_office[:address],
          City: post_office[:city],
          Region: post_office[:state],
          Postal: post_office[:zip_code_5],
        ).first.location

        {
          **post_office,
          lonlat: RGeo::Geos.factory(srid: UspsIppCachedLocations::WGS84_SRID).point(
            geocoded_post_office.longitude, geocoded_post_office.latitude
          ),
        }
      end
    end
  end
end
