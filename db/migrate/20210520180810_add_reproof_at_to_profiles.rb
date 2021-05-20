class AddReproofAtToProfiles < ActiveRecord::Migration[6.1]
  def change
    add_column :profiles, :reproof_at, :datetime, null: true
  end
end
