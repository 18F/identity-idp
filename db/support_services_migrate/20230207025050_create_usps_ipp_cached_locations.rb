class CreateUspsIppCachedLocations < ActiveRecord::Migration[7.0]
  def change
    create_table :usps_ipp_cached_locations do |t|
      t.st_point :lonlat
      t.json 'usps_attributes'
      t.timestamps
    end
  end
end
