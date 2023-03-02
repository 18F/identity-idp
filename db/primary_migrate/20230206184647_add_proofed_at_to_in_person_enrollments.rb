class AddProofedAtToInPersonEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments, :proofed_at, :timestamp, comment: 'timestamp when user attempted to proof at a Post Office'
  end
end
