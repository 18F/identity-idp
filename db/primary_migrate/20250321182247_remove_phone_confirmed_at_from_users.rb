class RemovePhoneConfirmedAtFromUsers < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :users, :phone_confirmed_at, :datetime }
  end
end
