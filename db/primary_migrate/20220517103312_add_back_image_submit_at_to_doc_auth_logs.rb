class AddBackImageSubmitAtToDocAuthLogs < ActiveRecord::Migration[6.1]
  def change
    add_column :doc_auth_logs, :back_image_submit_at, :datetime
    add_column :doc_auth_logs, :capture_mobile_back_image_submit_at, :datetime
    add_column :doc_auth_logs, :mobile_back_image_submit_at, :datetime
  end
end
