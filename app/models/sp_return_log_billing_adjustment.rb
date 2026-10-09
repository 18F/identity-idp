# frozen_string_literal: true

# A billing fact decided after a return-log row was written. Return-log rows are never updated,
# so anything that changes how one is invoiced is a new row here, and the invoice queries read
# both tables. Rows are append-only: once written they are neither updated nor deleted.
#
# * exclude_from_billing: the referenced row is a service provider's sign-in that is not
#   invoiced because a delegated token was issued for that sign-in; the agency receiving the
#   token is billed through `delegated_return_log` instead. `resolved_via` records how the
#   sign-in row was found, so use of the database fallback can be measured.
# * delegated_token_issued: the referenced row is a delegated row and `token_exchange_token` is
#   the issuance record that wrote it. Reports follow this link to the acting service provider,
#   the API and whether the person verified identity in that sign-in.
class SpReturnLogBillingAdjustment < ApplicationRecord
  enum :adjustment_type, { exclude_from_billing: 1, delegated_token_issued: 2 }
  enum :resolved_via, { cache: 1, database_fallback: 2 }, prefix: :resolved_via

  belongs_to :sp_return_log, inverse_of: :billing_adjustments
  belongs_to :delegated_return_log, class_name: 'SpReturnLog', optional: true, inverse_of: false
  belongs_to :token_exchange_token, optional: true, inverse_of: false

  validates :adjustment_type, presence: true

  # SQL predicate for invoice queries: true for a return-log row no adjustment excludes. `EXISTS`
  # excludes a sign-in once however many agencies' exchanges each wrote an adjustment for it.
  # @param table [String] the alias of `sp_return_logs` in the enclosing query
  def self.not_excluded_sql(table: 'sp_return_logs')
    <<~SQL.squish
      NOT EXISTS (
        SELECT 1 FROM sp_return_log_billing_adjustments adjustments
        WHERE adjustments.sp_return_log_id = #{table}.id
          AND adjustments.adjustment_type = #{adjustment_types.fetch('exclude_from_billing')}
      )
    SQL
  end

  # SQL expression for the partner report: true when the approval the delegated row was issued
  # under records that the person verified identity during that sign-in, read from the token's
  # issuance record through the `delegated_token_issued` link. False for a direct row.
  # @param table [String] the alias of `sp_return_logs` in the enclosing query
  def self.proofed_in_session_sql(table: 'sp_return_logs')
    <<~SQL.squish
      EXISTS (
        SELECT 1 FROM sp_return_log_billing_adjustments links
        JOIN token_exchange_tokens tokens ON tokens.id = links.token_exchange_token_id
        JOIN token_exchange_grants grants ON grants.id = tokens.grant_id
        WHERE links.sp_return_log_id = #{table}.id
          AND links.adjustment_type = #{adjustment_types.fetch('delegated_token_issued')}
          AND grants.proofed_in_session = true
      )
    SQL
  end

  def readonly?
    persisted?
  end
end
