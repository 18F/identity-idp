class AddSocureDocvCaptureAppUrlToDocumentCaptureSessionsWComment < ActiveRecord::Migration[7.2]
  def change
    add_column :document_capture_sessions, :socure_docv_capture_app_url, :string, comment: 'sensitive=false'
  end
end
