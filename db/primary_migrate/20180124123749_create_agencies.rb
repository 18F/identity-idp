class CreateAgencies < ActiveRecord::Migration[5.1]
  def change
    create_table :agencies do |t|
      t.string   "name", null: false
    end
    add_index :agencies, ["name"], name: "index_agencies_on_name", unique: true, using: :btree
  end
end
