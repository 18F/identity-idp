class CreateUspsIppLocationsCacheTables < ActiveRecord::Migration[7.0]
  def change
    create_table :usps_ipp_locations_cache_tables do |t|
      t.timestamps
    end
  end
end
