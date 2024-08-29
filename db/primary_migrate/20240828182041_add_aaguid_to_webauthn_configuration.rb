class AddAaguidToWebauthnConfiguration < ActiveRecord::Migration[7.1]
  def change
    add_column :webauthn_configurations, :aaguid, :string
  end
end
