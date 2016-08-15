class RenameUserMobileToPhone < ActiveRecord::Migration
  def change
    rename_column :users, :mobile, :phone
    rename_column :users, :mobile_confirmed_at, :phone_confirmed_at
  end
end
