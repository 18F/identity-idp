class CreateDuplicateProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :duplicate_profiles do |t|
      t.string :service_provider, limit: 255, null: false, comment: 'sensitive=false'
      t.bigint :profile_ids, array:true, null: false, comment: 'sensitive=false'
      t.datetime :closed_at, null: false, comment: 'sensitive=false'
      t.boolean :self_serviced, null: true, comment: 'sensitive=false'
      t.boolean :fraud_investigation_conclusive, null: true, comment: 'sensitive=false'

      t.timestamps comment: 'sensitive=false'
    end

    add_index(:duplicate_profiles, [:service_provider, :profile_ids], unique: true)
    add_index(:duplicate_profiles, :profile_ids, using: 'gin')
  end
end
