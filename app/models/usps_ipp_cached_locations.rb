class UspsIppCachedLocations < PostgisDataApplicationRecord
  self.table_name = "usps_ipp_cached_locations"

  FIFTY_MILES_IN_METERS = 50 * 1609

  def self.query_by_point(longitude, latitude, within = FIFTY_MILES_IN_METERS)
    # https://postgis.net/docs/ST_Point.html
    # For geodetic coordinates, X is longitude and Y is latitude

    UspsIppCachedLocations.where("ST_DWithin(lonlat::geography,'SRID=4326;POINT(#{longitude} #{latitude})'::geography, #{within})")
  end
end
