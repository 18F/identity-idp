class AddDocumentTypeRequestedToInPersonEnrollments < ActiveRecord::Migration[8.0]
  def change
    # Add new column alongside the old one for 50/50 deployment compatibility
    add_column :in_person_enrollments, :document_type_requested, :integer, comment: 'sensitive=false'
    
    # Copy existing data from old column to new column
    safety_assured do
      execute <<-SQL
        UPDATE in_person_enrollments 
        SET document_type_requested = document_type 
        WHERE document_type IS NOT NULL;
      SQL
    end
    
    # NOTE: The old column 'document_type' will be removed in a future migration
    # after all instances are using the new column name
  end
end
