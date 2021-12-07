class AddPlatformAuthenticatorToWebauthnConfiguration < ActiveRecord::Migration[6.1]
  def change
    add_column :webauthn_configurations, :platform_authenticator, :boolean
  end
end
