class CreateInPersonEnrollments < ActiveRecord::Migration[6.1]
  def change
    create_table :in_person_enrollments,
                 comment: 'Details and status of an in-person proofing enrollment for one '\
                 'user and profile' do |t|
      t.references :user, null: false, foreign_key: true,
                          comment: 'Foreign key to the user this enrollment belongs to'
      t.references :profile, null: false, foreign_key: true,
                             comment: 'Foreign key to the profile this enrollment belongs to'
      t.string :enrollment_code, comment: 'The code returned by the USPS service'
      t.datetime :status_check_attempted_at, comment: 'The last time a status check was attempted'
      t.datetime :status_updated_at,
                 comment: 'The last time the status was successfully updated with a value from '\
                 'the USPS API'
      t.integer :status, default: 0, comment: 'The status of the enrollment'

      t.timestamps
    end
    add_index :in_person_enrollments, [:user_id, :status], unique: true, where: '(status = 0)'
  end
end
