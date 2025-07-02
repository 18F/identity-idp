class UpdateSensitiveColumnsName < ActiveRecord::Migration[8.0]
  def change
    change_column_comment :webauthn_configurations, :name, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :auth_app_configurations, :name, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :piv_cac_configurations, :name, from: "sensitive=false", to: "sensitive=true"
  end
end
