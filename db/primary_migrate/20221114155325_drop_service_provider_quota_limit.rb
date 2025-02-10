class DropServiceProviderQuotaLimit < ActiveRecord::Migration[7.0]
  def change
    remove_index :service_provider_quota_limits, %i[issuer ial], unique: true

    drop_table :service_provider_quota_limits do |t|
      t.string :issuer, null: false
      t.integer :ial, null: false, limit: 1
      t.integer :percent_full
    end
  end
end
