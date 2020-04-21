class CreateServiceProviderQuotas < ActiveRecord::Migration[5.1]
  def change
    create_table :service_provider_quotas do |t|
      t.string :issuer, null: false
      t.integer :ial, null: false, limit: 1
      t.integer :percent_full
    end
    add_index :service_provider_quotas, %i[issuer ial], unique: true
  end
end
