class CreateUserProofingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :user_proofing_events, id: :string do |t|
      t.string :encrypted_events, null: false, comment: 'sensitive=true'
      t.bigint :profile_id, null: false, comment: 'sensitive=false'
      t.jsonb :service_providers_sent, null: false, default: {}, comment: 'sensitive=false'
      t.string :cost, null: false, comment: 'sensitive=true'
      t.string :salt, null: false, comment: 'sensitive=true'

      t.timestamps

      t.index :profile_id, unique: false
    end
  end
end
