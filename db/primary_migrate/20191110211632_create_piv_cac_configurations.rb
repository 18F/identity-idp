class CreatePivCacConfigurations < ActiveRecord::Migration[5.1]
  def change
    create_table :piv_cac_configurations do |t|
      t.integer :user_id, null: false
      t.string :x509_dn_uuid, null: false
      t.string :name, null: false
      t.timestamps
      t.index [:user_id, :created_at], unique: true
      t.index [:x509_dn_uuid], unique: true
      t.index [:user_id, :name], unique: true
    end
  end
end
