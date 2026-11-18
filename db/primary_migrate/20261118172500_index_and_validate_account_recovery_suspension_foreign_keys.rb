# frozen_string_literal: true

class IndexAndValidateAccountRecoverySuspensionForeignKeys < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  # Only suspended rows are indexed, so each index stays nearly empty. Without
  # it, deleting an account recovery request scans every one of these tables to
  # check the foreign key.
  INDEX_NAMES = {
    phone_configurations: 'index_phone_configs_on_account_recovery_request_id',
    auth_app_configurations: 'index_auth_app_configs_on_account_recovery_request_id',
    webauthn_configurations: 'index_webauthn_configs_on_account_recovery_request_id',
    piv_cac_configurations: 'index_piv_cac_configs_on_account_recovery_request_id',
    backup_code_configurations: 'index_backup_code_configs_on_account_recovery_request_id',
  }.freeze

  def change
    INDEX_NAMES.each do |table, name|
      add_index table, :account_recovery_request_id,
                name:,
                where: 'account_recovery_request_id IS NOT NULL',
                algorithm: :concurrently

      # Validated after the index is built so the check reads the index rather
      # than the whole table.
      validate_foreign_key table, :account_recovery_requests
    end
  end
end
