class AddDealDataToServiceProviders < ActiveRecord::Migration[5.2]
  def change
    add_column :service_providers, :deal_id, :string
    add_column :service_providers, :launch_date, :date
    add_column :service_providers, :iaa, :string
    add_column :service_providers, :iaa_start_date, :date
    add_column :service_providers, :iaa_end_date, :date
  end
end
