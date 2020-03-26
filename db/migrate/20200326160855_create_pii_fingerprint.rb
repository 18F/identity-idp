class CreatePiiFingerprint < ActiveRecord::Migration[5.2]
  def change
    add_column :profiles, :name_zip_birth_year_signature, :string

    # This column is empty and the table here is small. This index should not
    # lock the table.
    safety_assured { add_index :profiles, :name_zip_birth_year_signature }
  end
end
