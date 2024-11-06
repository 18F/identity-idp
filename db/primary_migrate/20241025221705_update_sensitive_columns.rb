class UpdateSensitiveColumns < ActiveRecord::Migration[7.2]
  def change
    #change columns to sensitive=true
    change_column_comment :profiles, :encrypted_pii_multi_region, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :profiles, :encrypted_pii_recovery_multi_region, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :users, :encrypted_recovery_code_digest_generated_at, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :users, :encrypted_password_digest_multi_region, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :users, :encrypted_recovery_code_digest_multi_region, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :phone_configurations, :encrypted_phone, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :phone_number_opt_outs, :encrypted_phone, from: "sensitive=false", to: "sensitive=true"
    change_column_comment :identities, :nonce, from: "sensitive=false", to: "sensitive=true"
  end
end
