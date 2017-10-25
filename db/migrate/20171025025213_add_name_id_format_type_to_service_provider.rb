class AddNameIdFormatTypeToServiceProvider < ActiveRecord::Migration[5.1]
  def change
    add_column :service_providers, :name_id_format_type, :string, null: true
  end
end
