class CreateRecoveryCodeConfigurations < ActiveRecord::Migration[5.1]
  def change
    create_table :backup_code_configurations do |t|
      t.integer :user_id, null: false
      t.text :code, null: false
      t.boolean :used, default: false
      t.timestamp :used_at
      t.timestamps
      t.index :user_id
      t.index :code
    end
  end
end
