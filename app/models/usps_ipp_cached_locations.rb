class UspsIppCachedLocations < PostgisDataApplicationRecord
  self.table_name = 'usps_ipp_cached_locations'

  # https://epsg.io/4326
  WGS84_SRID = 4326

  FIFTY_MILES_IN_METERS = 50 * 1609

  def self.query_by_point(longitude, latitude, within = FIFTY_MILES_IN_METERS)
    # https://postgis.net/docs/ST_Point.html
    # For geodetic coordinates, X is longitude and Y is latitude
    centroid = "'SRID=#{FIFTY_MILES_IN_METERS};POINT(#{longitude} #{latitude})'::geography"

    radius_query = "ST_DWithin(lonlat::geography,#{centroid}, #{within})"
    UspsIppCachedLocations.where(radius_query)
  end
end
