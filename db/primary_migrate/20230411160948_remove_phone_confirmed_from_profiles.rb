class RemovePhoneConfirmedFromProfiles < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :profiles, :phone_confirmed, :boolean }
  end
end
