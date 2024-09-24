class CreateSpUpgradedBiometricProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :sp_upgraded_biometric_profiles do |t|
      t.datetime :upgraded_at, null: false
      t.references :user, null: false
      t.string :idv_level, null: false
      t.string :issuer, null: false

      t.timestamps

      t.index [:issuer, :upgraded_at]
    end
  end
end
