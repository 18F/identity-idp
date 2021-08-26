class DocAuthLogsDropNoSpCampaign < ActiveRecord::Migration[6.1]
  def change
    safety_assured { remove_column :doc_auth_logs, :no_sp_campaign, :string }
  end
end
