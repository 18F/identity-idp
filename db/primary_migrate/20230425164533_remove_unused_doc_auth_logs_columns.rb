class RemoveUnusedDocAuthLogsColumns < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      remove_column :doc_auth_logs, :send_link_view_at, :datetime
      remove_column :doc_auth_logs, :send_link_view_count, :integer
      remove_column :doc_auth_logs, :email_sent_view_at, :datetime
      remove_column :doc_auth_logs, :email_sent_view_count, :integer
    end
  end
end
