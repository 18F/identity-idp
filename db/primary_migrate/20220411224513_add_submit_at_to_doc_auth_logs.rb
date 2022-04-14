class AddSubmitAtToDocAuthLogs < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :verify_submit_at, :datetime
      add_column :doc_auth_logs, :verify_phone_submit_count, :integer, default: 0
      add_column :doc_auth_logs, :verify_phone_submit_at, :datetime
      add_column :doc_auth_logs, :document_capture_submit_at, :datetime
    end
  end
end
