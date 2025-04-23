class AddDocumentTypeToInPersonEnrollments < ActiveRecord::Migration[8.0]
  def change
    add_column :in_person_enrollments, :document_type, :integer, comment: 'sensitive=false'
  end
end
