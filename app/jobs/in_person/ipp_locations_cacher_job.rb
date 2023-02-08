module InPerson
  class IppLocationsCacherJob < ApplicationJob
    include ArcgisApi

    def perform(post_offices)
      UspsIppCachedLocations.upsert_all(
        post_offices.map do |post_office|
          {
            address: post_office[:address],
            city: post_office[:city],
            state: post_office[:state],
            zip: post_office[:zip_code_5],

            usps_attributes: post_office,
            lonlat: geocode(post_office),
          }
        end,
        unique_by: [:address, :city, :state, :zip],
      )
    end

    # TODO: implement batch geocoder
    def geocode(post_office)
      geocoded_post_office = Geocoder.new.find_address_candidates(
        Address: post_office[:address],
        City: post_office[:city],
        Region: post_office[:state],
        Postal: post_office[:zip_code_5],
      ).first.location

      RGeo::Geos.factory(srid: UspsIppCachedLocations::WGS84_SRID).point(
        geocoded_post_office.longitude, geocoded_post_office.latitude
      )
    end
  end
end
