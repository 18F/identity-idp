class AddProfilesTable < ActiveRecord::Migration
  def change
    create_table :profiles do |tbl|
      tbl.integer :user_id, null: false
      tbl.boolean :active, null: false, default: false
      tbl.datetime :verified_at
      tbl.datetime :activated_at
      tbl.timestamps null: false

      tbl.string :first_name
      tbl.string :middle_name
      tbl.string :last_name
      tbl.string :address1
      tbl.string :address2
      tbl.string :city
      tbl.string :state
      tbl.string :zipcode
      tbl.string :ssn
      tbl.string :dob
      tbl.string :phone
      tbl.string :vendor
    end

    add_index :profiles, :user_id
    add_index "profiles", ["user_id", "active"], unique: true, where: "(active = true)", using: :btree
  end
end
