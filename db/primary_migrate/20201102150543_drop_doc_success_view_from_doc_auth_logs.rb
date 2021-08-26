class DropDocSuccessViewFromDocAuthLogs < ActiveRecord::Migration[5.2]
  def up
    safety_assured do
      remove_column :doc_auth_logs, :doc_success_view_at
      remove_column :doc_auth_logs, :doc_success_view_count
    end
  end

  def down
    add_column :doc_auth_logs, :doc_success_view_at, :datetime
    add_column :doc_auth_logs, :doc_success_view_count, :integer, default: 0
  end
end
