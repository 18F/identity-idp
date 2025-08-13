class RenameDocumentTypeToDocumentTypeRequestedInInPersonEnrollments < ActiveRecord::Migration[8.0]
  def change
    # Step 1: Create new column
    add_column :in_person_enrollments, :document_type_requested, :integer, comment: 'sensitive=false'
    
    # Step 2: Copy data from old column to new column
    safety_assured do
      execute <<-SQL
        UPDATE in_person_enrollments 
        SET document_type_requested = document_type 
        WHERE document_type IS NOT NULL;
      SQL
    end
    
    # Step 3: Remove old column (in a separate migration this would be later)
    safety_assured { remove_column :in_person_enrollments, :document_type }
  end
end
