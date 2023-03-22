class AddCaptureSecondaryIdEnabledToInPersonEnrollments < ActiveRecord::Migration[7.0]
  def change
    add_column :in_person_enrollments,
               :capture_secondary_id_enabled,
               :boolean,
               default: false,
               comment: 'record and proof state ID and residential addresses separately'
  end
end
