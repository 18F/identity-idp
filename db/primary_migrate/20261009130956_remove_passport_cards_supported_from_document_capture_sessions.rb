class RemovePassportCardsSupportedFromDocumentCaptureSessions < ActiveRecord::Migration[8.1]
  def change
    safety_assured do
      remove_column :document_capture_sessions, :passport_cards_supported, :boolean,
                    default: false, comment: 'sensitive=false'
    end
  end
end
