class AddPassportCardsSupportedToDocumentCaptureSession < ActiveRecord::Migration[8.0]
  def change
    add_column :document_capture_sessions, :passport_cards_supported, :boolean, default: false,
                                                                                null: false
  end
end
