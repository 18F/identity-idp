# frozen_string_literal: true

class ValidateDelegatedIssuanceLogForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :delegated_issuance_logs, :sp_return_logs,
                         column: :actor_return_log_id
    validate_foreign_key :delegated_issuance_logs, :sp_return_logs,
                         column: :target_return_log_id
  end
end
