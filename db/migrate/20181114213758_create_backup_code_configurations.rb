class CreateRecoveryCodeConfigurations < ActiveRecord::Migration[5.1]
  def change
    create_table :backup_code_configurations do |t|
      t.integer :user_id, null: false
      t.string :code_fingerprint, default:'', null: false
      t.string :encrypted_code, default:'', null: false
      t.boolean :used, default: false
      t.timestamp :used_at
      t.timestamps
      t.index :user_id
      t.index :code_fingerprint
    end
  end
end
