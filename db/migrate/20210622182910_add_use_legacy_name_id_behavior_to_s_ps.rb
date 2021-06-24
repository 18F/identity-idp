class AddUseLegacyNameIdBehaviorToSPs < ActiveRecord::Migration[6.1]
  def change
    add_column :service_providers, :use_legacy_name_id_behavior, :boolean
    change_column_default :service_providers, :use_legacy_name_id_behavior, false
  end
end
