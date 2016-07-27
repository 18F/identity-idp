class AddProfilesSsnUnique < ActiveRecord::Migration
  def change
    add_index :profiles, [:ssn, :active], unique: true, where: "(active = true)", using: :btree
  end
end
