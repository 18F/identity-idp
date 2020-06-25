class DropDealIdFromServiceProviders < ActiveRecord::Migration[5.1]
  def up
    safety_assured do
      remove_column :service_providers, :deal_id
    end
  end

  def down
    add_column :service_providers, :deal_id, :string
  end
end
