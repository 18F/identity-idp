class CreatePiiFingerprint < ActiveRecord::Migration[5.2]
  def change
    add_column :profiles, :pii_fingerprint, :string
    # This column is empty and the table here is small. This index should not
    # lock the table.
    safety_assured { add_index :profiles, :pii_fingerprint }
  end
end
