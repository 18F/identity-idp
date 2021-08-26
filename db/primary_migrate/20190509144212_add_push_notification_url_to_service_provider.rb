class AddPushNotificationUrlToServiceProvider < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_column :service_providers, :push_notification_url, :string
  end
end
