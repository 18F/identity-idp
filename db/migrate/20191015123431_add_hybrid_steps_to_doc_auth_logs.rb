class AddHybridStepsToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :capture_mobile_back_image_view_at, :datetime
      add_column :doc_auth_logs, :capture_mobile_back_image_view_count, :integer, default: 0
      add_column :doc_auth_logs, :capture_complete_view_at, :datetime
      add_column :doc_auth_logs, :capture_complete_view_count, :integer, default: 0
      add_column :doc_auth_logs, :capture_mobile_back_image_submit_count, :integer, default: 0
      add_column :doc_auth_logs, :capture_mobile_back_image_error_count, :integer, default: 0
    end
  end
end
