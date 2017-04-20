class AddProfilePhoneConfirmed < ActiveRecord::Migration
  def change
    add_column :profiles, :phone_confirmed, :boolean, default: false, null: false
  end
end
