class ValidateInPersonEnrollmentsIssuer < ActiveRecord::Migration[7.0]
  def change
    validate_foreign_key :in_person_enrollments, :service_providers, column: :issuer, primary_key: :issuer
  end
end
