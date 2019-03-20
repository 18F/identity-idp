class AddDisavowalTokenFingerprintToEvents < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_column :events, :disavowed_at, :timestamp
    add_column :events, :disavowal_token_fingerprint, :string
    add_index :events, :disavowal_token_fingerprint, algorithm: :concurrently
  end
end
