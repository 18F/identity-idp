class AddLivenessStepsToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :selfie_view_at, :datetime
      add_column :doc_auth_logs, :selfie_view_count, :integer, default: 0
      add_column :doc_auth_logs, :selfie_submit_count, :integer, default: 0
      add_column :doc_auth_logs, :selfie_error_count, :integer, default: 0
    end
  end
end
