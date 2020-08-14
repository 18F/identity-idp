class AddLastDocumentErrorToDocAuthLogs < ActiveRecord::Migration[5.1]
  def change
    add_column :doc_auth_logs, :last_document_error, :string
  end
end
