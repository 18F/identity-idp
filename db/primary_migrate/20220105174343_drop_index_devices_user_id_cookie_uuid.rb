class DropIndexDevicesUserIdCookieUuid < ActiveRecord::Migration[6.1]
  def change
    remove_index :devices, column: [:user_id, :cookie_uuid], name: "index_device_user_id_cookie_uuid"
  end
end
