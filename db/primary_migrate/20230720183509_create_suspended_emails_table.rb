class CreateSuspendedEmailsTable < ActiveRecord::Migration[7.0]
  def change
    create_table :suspended_emails do |t|
      t.references :email_address, null: false
      t.string :digested_base_email, null: false, index: true
      t.timestamps
    end
  end
end
