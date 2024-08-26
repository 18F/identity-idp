class DropAamvaFromDocAuthLogs < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :doc_auth_logs, :aamva, :boolean
    end
  end
end
