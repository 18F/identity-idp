class AddAuthenticatorDataFlagsToWebauthnConfiguration < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!
  def change
    add_column :webauthn_configurations, :authenticator_data_flags, :jsonb
  end
end
