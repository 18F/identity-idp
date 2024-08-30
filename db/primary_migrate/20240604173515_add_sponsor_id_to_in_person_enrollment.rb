class AddSponsorIdToInPersonEnrollment < ActiveRecord::Migration[7.1]
  def change
    add_column :in_person_enrollments, :sponsor_id, :string
  end
end
