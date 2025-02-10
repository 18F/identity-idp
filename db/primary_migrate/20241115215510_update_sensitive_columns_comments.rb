class UpdateSensitiveColumnsComments < ActiveRecord::Migration[7.2]
  def change
    #change columns to sensitive=true
    change_column_comment :phone_number_opt_outs, :phone_fingerprint, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :in_person_enrollments, :selected_location_details, from: "The location details of the Post Office the user selected (including title, address, hours of operation) sensitive=false", to: "The location details of the Post Office the user selected (including title, address, hours of operation) sensitive=true"
  end
end
