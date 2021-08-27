class UspsConfirmationCodesDropLetterExpiredSentAt < ActiveRecord::Migration[6.1]
  def change
    remove_index :usps_confirmation_codes, columns: [:bounced_at, :letter_expired_sent_at, :created_at], name: :index_ucc_expired_letters
    safety_assured { remove_column :usps_confirmation_codes, :letter_expired_sent_at }
  end
end
