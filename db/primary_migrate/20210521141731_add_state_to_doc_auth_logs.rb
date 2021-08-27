class AddStateToDocAuthLogs < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :state, :string
    end
  end
end
