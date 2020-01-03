class CreateAuthAppConfigurations < ActiveRecord::Migration[5.1]
  def change
    create_table :auth_app_configurations do |t|
      t.integer :user_id, null: false
      t.string :encrypted_otp_secret_key, null: false
      t.string :name, null: false
      t.integer :totp_timestamp
      t.timestamps
      t.index [:user_id, :created_at], unique: true
      t.index [:user_id, :name], unique: true
    end
  end
end
