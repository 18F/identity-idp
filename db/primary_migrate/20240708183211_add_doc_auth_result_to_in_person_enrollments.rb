class AddDocAuthResultToInPersonEnrollments < ActiveRecord::Migration[7.1]
  def change
    add_column :in_person_enrollments, :doc_auth_result, :string
    add_column :document_capture_sessions, :last_doc_auth_result, :string
  end
end
