class CreateServiceProviderRequests < ActiveRecord::Migration[4.2]
  def change
    create_table :service_provider_requests do |t|
      t.string :issuer, null: false
      t.string :loa, null: false
      t.string :url, null: false
      t.string :uuid, null: false

      t.timestamps null: false

      t.index :uuid, unique: true
    end
  end
end
