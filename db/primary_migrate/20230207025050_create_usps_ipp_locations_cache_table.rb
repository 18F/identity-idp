class CreateUspsIppLocationsCacheTable < ActiveRecord::Migration[7.0]
  def change
    create_table :usps_ipp_locations_cache_tables do |t|
      t.st_point :lonlat
      t.json 'attributes'
      t.timestamps
    end
  end
end
