class AddSignedResponseMessageRequestedToServiceProvider < ActiveRecord::Migration[5.1]
  def up
    add_column :service_providers, :signed_response_message_requested, :boolean
    change_column_default :service_providers, :signed_response_message_requested, false
  end

  def down
    remove_column :service_providers, :signed_response_message_requested
  end
end
