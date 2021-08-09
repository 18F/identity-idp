class DropPlaintextColumns < ActiveRecord::Migration[4.2]
  def change
    remove_column :users, :phone_plain
    remove_column :users, :otp_secret_key
  end
end
