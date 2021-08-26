class AddIssuerToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    add_column :doc_auth_logs, :issuer, :string
  end
end
