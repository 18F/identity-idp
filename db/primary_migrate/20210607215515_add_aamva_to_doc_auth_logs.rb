class AddAamvaToDocAuthLogs < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_column :doc_auth_logs, :aamva, :boolean
    end
  end
end
