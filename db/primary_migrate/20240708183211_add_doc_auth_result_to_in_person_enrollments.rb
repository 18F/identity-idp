class AddDocAuthResultToInPersonEnrollments < ActiveRecord::Migration[7.1]
  def change
    add_column :in_person_enrollments, :doc_auth_result, :string
  end
end
