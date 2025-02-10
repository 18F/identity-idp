class DropIal2Quota < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :service_providers, :ial2_quota, :integer }
  end
end
