class AddNoSpTrackingToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :no_sp_at, :datetime
      add_column :doc_auth_logs, :no_sp_campaign, :string
    end
  end
end
