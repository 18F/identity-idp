class RemoveReproofAtFromProfiles < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :profiles, :reproof_at, :date }
  end
end
