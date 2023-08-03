class AddMrChipertextColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :encrypted_password_digest_mr, :string
    add_column :users, :encrypted_recovery_code_digest_mr, :string
    add_column :profiles, :encrypted_pii_mr, :text
    add_column :profiles, :encrypted_pii_recovery_mr, :text
    add_column :usps_confirmations, :entry_mr, :text, null: false
  end
end
