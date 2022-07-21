class CreateNewUniqueIdUspsService < ActiveRecord::Migration[6.1]
  def change
    add_column :in_person_enrollments, :unique_id, :string, :uniqueness => true, comment: "Unique ID to use with the USPS service"
    end
  end
