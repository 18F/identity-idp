class AddRememberDeviceRevokedAtToUser < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :remember_device_revoked_at, :datetime
  end
end
