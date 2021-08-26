class AddExpiredToUspsConfirmationCodes < ActiveRecord::Migration[5.1]
  disable_ddl_transaction!

  def change
    add_column :usps_confirmation_codes, :letter_expired_sent_at, :timestamp
    add_index :usps_confirmation_codes, %i[bounced_at letter_expired_sent_at created_at],
              algorithm: :concurrently, name: 'index_ucc_expired_letters'
  end
end
