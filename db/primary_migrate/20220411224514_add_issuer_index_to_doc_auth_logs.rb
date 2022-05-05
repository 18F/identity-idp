class AddIssuerIndexToDocAuthLogs < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :doc_auth_logs, :issuer, algorithm: :concurrently
  end
end
