class AddReproofAtToProfiles < ActiveRecord::Migration[6.1]
  def change
    add_column :profiles, :reproof_at, :date, null: true
  end
end
