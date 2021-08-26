class AddMiscToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :mobile_front_image_submit_count, :integer, default: 0
      add_column :doc_auth_logs, :mobile_front_image_error_count, :integer, default: 0
      add_column :doc_auth_logs, :mobile_back_image_submit_count, :integer, default: 0
      add_column :doc_auth_logs, :mobile_back_image_error_count, :integer, default: 0
    end
  end
end
