class AddProfilePhoneConfirmed < ActiveRecord::Migration[4.2]
  def change
    add_column :profiles, :phone_confirmed, :boolean, default: false, null: false
  end
end
