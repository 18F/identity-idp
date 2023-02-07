class UspsIppCachedLocations < SupportServiceApplicationRecord
  self.table_name = "usps_ipp_cached_locations"

  def self.query_by_point(longitude, latitude)
    query = RGeo::Geos.factory(srid: 4326).point(longitude, latitude)
    # change to https://postgis.net/docs/ST_Within.html
    locations = UspsIppLocationsCacheTable.arel_table[:lonlat].st_contains(query)
    UspsIppLocationsCacheTable.where(UspsIppLocationsCacheTable.arel_table[:lonlat].st_contains(query))
  end
end
