# frozen_string_literal: true

# Append-only record of billing facts decided after a return-log row was written. A return-log
# row is never updated; a change to how it is invoiced is a new row here, and the invoice
# queries read both.
#
# Two kinds of row, told apart by `adjustment_type`:
#
# * exclude_from_billing: `sp_return_log_id` is a service provider's sign-in row that is no
#   longer invoiced because a delegated token was issued for that sign-in and the agency that
#   received it is billed instead. `delegated_return_log_id` is the agency's row and
#   `token_exchange_token_id` the token; `resolved_via` says whether the sign-in row was found
#   through the short-lived cache link or the database fallback.
# * delegated_token_issued: `sp_return_log_id` is a delegated row and `token_exchange_token_id`
#   the token whose issuance wrote it. This is the link reports follow to the issuance record
#   (service provider, API, approval) for a delegated row.
class CreateSpReturnLogBillingAdjustments < ActiveRecord::Migration[8.1]
  def change
    create_table :sp_return_log_billing_adjustments do |t|
      t.bigint :sp_return_log_id, null: false, comment: 'sensitive=false'
      t.integer :adjustment_type, null: false, comment: 'sensitive=false'
      t.bigint :delegated_return_log_id, comment: 'sensitive=false'
      t.bigint :token_exchange_token_id, comment: 'sensitive=false'
      t.integer :resolved_via, comment: 'sensitive=false'
      t.datetime :created_at, null: false, comment: 'sensitive=false'

      t.index [:sp_return_log_id, :adjustment_type],
              name: 'index_sp_return_log_billing_adjustments_on_log_and_type'
      t.index :delegated_return_log_id,
              name: 'index_sp_return_log_billing_adjustments_on_delegated_log_id'
      t.index :token_exchange_token_id,
              name: 'index_sp_return_log_billing_adjustments_on_token_id'
    end
  end
end
