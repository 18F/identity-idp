class AddNoSpTrackingToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    add_column :doc_auth_logs, :no_sp_session_started_at, :datetime
    add_column :doc_auth_logs, :no_sp_campaign, :string
  end
end
