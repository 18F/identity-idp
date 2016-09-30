class AddSsnSignatureToProfile < ActiveRecord::Migration
  def change
    add_column :profiles, :ssn_signature, :string, limit: 64
    # one active ssn per user
    add_index :profiles, [:user_id, :ssn_signature, :active], unique: true, where: "(active = true)", using: :btree
    # ssn unique across all active profiles
    add_index :profiles, [:ssn_signature, :active], unique: true, where: "(active = true)", using: :btree
    # optimize ssn lookups
    add_index :profiles, :ssn_signature
  end
end
