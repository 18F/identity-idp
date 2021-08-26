class DevicesCookieUuidIndex < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :devices, :cookie_uuid, algorithm: :concurrently
  end
end
