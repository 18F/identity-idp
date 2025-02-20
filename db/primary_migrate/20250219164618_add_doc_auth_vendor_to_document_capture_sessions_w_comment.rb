class AddDocAuthVendorToDocumentCaptureSessionsWComment < ActiveRecord::Migration[7.2]
  def up
    add_column :document_capture_sessions, :doc_auth_vendor, :string, comment: 'sensitive=false'
  end

  def down
    remove_column :document_capture_sessions, :doc_auth_vendor
  end
end
