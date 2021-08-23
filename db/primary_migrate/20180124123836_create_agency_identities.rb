class CreateAgencyIdentities < ActiveRecord::Migration[5.1]
  def change
    create_table :agency_identities do |t|
      t.integer  "user_id", null: false
      t.integer  "agency_id", null: false
      t.string   "uuid", null: false
    end
    add_index :agency_identities, ["user_id", "agency_id"], name: "index_agency_identities_on_user_id_and_agency_id", unique: true, using: :btree
    add_index :agency_identities, ["uuid"], name: "index_agency_identities_on_uuid", unique: true, using: :btree
  end
end
