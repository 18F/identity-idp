class AddSignInNewDeviceToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :sign_in_new_device, :datetime
  end
end
