# frozen_string_literal: true

class AddAccountRecoverySuspensionToMfaConfigurations < ActiveRecord::Migration[8.1]
  # Each column is added and committed on its own, so no table stays locked
  # while the next one waits, and a partial run is safe to repeat.
  disable_ddl_transaction!

  # No foreign key on purpose. It would need an index to keep deleting a
  # recovery request cheap, and building one reads every row of these tables.
  # The column is only ever queried within a single user's rows.
  def change
    %i[
      phone_configurations auth_app_configurations webauthn_configurations
      piv_cac_configurations backup_code_configurations
    ].each do |table|
      add_column table, :account_recovery_request_id, :bigint,
                 comment: 'sensitive=false', if_not_exists: true
    end
  end
end
