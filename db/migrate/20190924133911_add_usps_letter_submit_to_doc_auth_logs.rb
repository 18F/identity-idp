class AddUspsLetterSubmitToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :usps_letter_sent_submit_count, :integer, default: 0
      add_column :doc_auth_logs, :usps_letter_sent_error_count, :integer, default: 0
      remove_column :doc_auth_logs, :usps_address_submit_at
      remove_column :doc_auth_logs, :usps_address_submit_count
      remove_column :doc_auth_logs, :usps_address_error_count
      remove_column :doc_auth_logs, :usps_letter_sent_view_count
      remove_column :doc_auth_logs, :usps_letter_sent_view_at
    end
  end
end
