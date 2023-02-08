class CreateUspsIppCachedLocations < ActiveRecord::Migration[7.0]
  def change
    create_table :usps_ipp_cached_locations do |t|
      t.st_point :lonlat, srid: 4326
      t.text :address
      t.text :city
      t.text :state
      t.text :zip
      t.jsonb 'usps_attributes'
      t.timestamps
    end

    add_index :usps_ipp_cached_locations, [:address, :city, :state, :zip],
              unique: true,
              name: 'usps_ipp_cached_locations_uniqueness_index'
  end
end
