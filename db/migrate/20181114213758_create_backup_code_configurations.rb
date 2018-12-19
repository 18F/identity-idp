class CreateBackupCodeConfigurations < ActiveRecord::Migration[5.1]
  def change
    create_table :backup_code_configurations do |t|
      t.integer :user_id, null: false
      t.string :code_fingerprint, default:'', null: false
      t.string :encrypted_code, default:'', null: false
      t.timestamp :used_at
      t.timestamps
      t.index [:user_id, :code_fingerprint], name: "index_bcc_on_user_id_code_fingerprint",
              unique: true
    end
  end
end
