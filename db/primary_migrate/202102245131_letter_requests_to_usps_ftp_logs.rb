class LetterRequestsToUspsFtpLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :letter_requests_to_usps_ftp_logs do |t|
      t.timestamp :ftp_at, null: false
      t.integer :letter_requests_count, null: false
    end
    add_index :letter_requests_to_usps_ftp_logs, %i[ftp_at]
  end
end
