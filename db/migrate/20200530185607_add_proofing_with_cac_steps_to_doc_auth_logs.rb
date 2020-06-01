class AddProofingWithCacStepsToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :choose_method_view_at, :datetime
      add_column :doc_auth_logs, :choose_method_view_count, :integer, default: 0
      add_column :doc_auth_logs, :present_cac_view_at, :datetime
      add_column :doc_auth_logs, :present_cac_view_count, :integer, default: 0
      add_column :doc_auth_logs, :present_cac_submit_count, :integer, default: 0
      add_column :doc_auth_logs, :present_cac_error_count, :integer, default: 0
      add_column :doc_auth_logs, :enter_info_view_at, :datetime
      add_column :doc_auth_logs, :enter_info_view_count, :integer, default: 0
      add_column :doc_auth_logs, :success_view_at, :datetime
      add_column :doc_auth_logs, :success_view_count, :integer, default: 0
    end
  end
end
