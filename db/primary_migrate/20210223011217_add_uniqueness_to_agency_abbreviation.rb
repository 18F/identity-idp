class AddUniquenessToAgencyAbbreviation < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :agencies, :abbreviation, unique: true, algorithm: :concurrently
  end
end
