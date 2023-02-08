class UspsIppCachedLocations < PostgisDataApplicationRecord
  self.table_name = "usps_ipp_cached_locations"

  def self.query_by_point(longitude, latitude)
    query = RGeo::Geos.factory(srid: 4326).point(longitude, latitude)
    # change to https://postgis.net/docs/ST_Within.html
    locations = UspsIppCachedLocations.arel_table[:lonlat].st_contains(query)
    UspsIppCachedLocations.where(UspsIppCachedLocations.arel_table[:lonlat].st_contains(query))
  end
end
