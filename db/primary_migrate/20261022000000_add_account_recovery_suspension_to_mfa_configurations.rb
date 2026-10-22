# frozen_string_literal: true

class AddAccountRecoverySuspensionToMfaConfigurations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    %i[
      phone_configurations auth_app_configurations webauthn_configurations
      piv_cac_configurations backup_code_configurations
    ].each do |table|
      add_column table, :account_recovery_request_id, :bigint, comment: 'sensitive=false'
      add_index table, :account_recovery_request_id, algorithm: :concurrently
      add_foreign_key table, :account_recovery_requests, validate: false
    end
  end
end
