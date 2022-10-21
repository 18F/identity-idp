class AddIssuerToInPersonEnrollments < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :in_person_enrollments, :issuer, :string, null: true, comment: "Issuer associated with the enrollment at time of creation"
    add_foreign_key :in_person_enrollments, :service_providers, column: :issuer, primary_key: :issuer, validate: false
  end
end
