# frozen_string_literal: true

class ValidateDelegatedIssuanceForeignKeys < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :delegated_issuances, :sp_return_logs,
                         column: :actor_return_log_id
    validate_foreign_key :delegated_issuances, :sp_return_logs,
                         column: :target_return_log_id
  end
end
