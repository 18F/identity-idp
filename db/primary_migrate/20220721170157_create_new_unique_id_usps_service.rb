class CreateNewUniqueIdUspsService < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_column :in_person_enrollments, :unique_id, :string, comment: "Unique ID to use with the USPS service"
    add_index :in_person_enrollments, :unique_id, unique: true, algorithm: :concurrently
  end
end
