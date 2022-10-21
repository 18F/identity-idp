class AddAddressAndLocationToInPersonEnrollment < ActiveRecord::Migration[6.1]
  def change
    add_column :in_person_enrollments, :current_address_matches_id, :boolean, comment: "True if the user indicates that their current address matches the address on the ID they're bringing to the Post Office."
    add_column :in_person_enrollments, :selected_location_details, :jsonb, comment: "The location details of the Post Office the user selected (including title, address, hours of operation)"
  end
end
