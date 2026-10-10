# frozen_string_literal: true

require 'csv'

module Reports
  # Monthly outcomes of delegated access, in two tables.
  #
  # The first is per service provider, agency and API, over the approvals (token_exchange_grants)
  # written during the month for the application that owns the API:
  #
  # * requested: approvals written, whatever happened next. The consent screen approves every
  #   requested application or cancels the sign-in, and a cancelled screen writes no row, so there
  #   is no count of applications declined on the screen; the nearest recorded "no" is the next
  #   column.
  # * withdrawn_before_use: the person revoked the approval before any token was issued under it.
  # * consented_not_exchanged: never exchanged for a token and the authorization has ended for a
  #   reason other than the person's withdrawal: revoked otherwise, the remembered period passed,
  #   or a single-authorization approval whose browser session is no longer the one the service
  #   provider connection is bound to.
  # * exchanged: at least one token was issued for this API under the approval, so a billable
  #   agency row exists.
  # * proofed_in_session_not_exchanged: the person verified identity during the sign-in that led
  #   to the approval and no token was ever issued under it, for any API: a verification no
  #   agency is billed for.
  #
  # An approval that is still current and unexchanged at report time falls in none of the last
  # four columns, so `requested` can exceed their sum. An approval replaced by a re-approval of
  # the same application is left out; its replacement is counted. An application with several
  # APIs appears once per API with the same approval counts and its own `exchanged` count.
  # `billing_issuer_has_agreement` says whether delegated access to the API is invoiced at all:
  # the API's billing issuer must be wired into a partner agreement, or its rows are recorded
  # and never billed.
  #
  # The second table is per service provider: its own sign-ins for the month that are still
  # billed to it (no delegated token was issued for the sign-in) and those waived because at least
  # one delegated token was issued and the agencies receiving the tokens were billed instead.
  # A sign-in the person cancelled at the consent screen writes no row and is counted nowhere.
  class DelegationOutcomesReport < BaseReport
    REPORT_NAME = 'delegation-outcomes-report'
    SIGN_INS_REPORT_NAME = 'delegation-sign-ins-report'
    HEADER = [
      'Service provider issuer',
      'Agency',
      'Resource server',
      'Billing issuer has agreement',
      'Requested',
      'Withdrawn before use',
      'Consented, not exchanged',
      'Exchanged',
      'Proofed in session, not exchanged',
    ].freeze
    SIGN_INS_HEADER = [
      'Service provider issuer',
      'Sign-ins billed to the service provider',
      'Sign-ins waived (delegated token issued)',
    ].freeze
    SUPERSEDED = 'superseded_by_new_consent'
    WITHDRAWN = AccountDelegationRevocation::REASON

    attr_reader :report_date

    # @param report_date [Time] any moment in the month to report on (the scheduler passes the
    #   end of the previous month's last day)
    # @return [String] the outcomes CSV
    def perform(report_date = Time.zone.yesterday.end_of_day)
      @report_date = report_date

      table = [HEADER] + rows.map(&:values)
      sign_ins_table = [SIGN_INS_HEADER] + sign_in_rows.map(&:values)
      csv = to_csv(table)

      save_report(REPORT_NAME, csv, extension: 'csv', now: report_date, timestamp_format: '%Y-%m')
      save_report(
        SIGN_INS_REPORT_NAME, to_csv(sign_ins_table),
        extension: 'csv', now: report_date, timestamp_format: '%Y-%m'
      )
      email_report(table, sign_ins_table)

      csv
    end

    def month_range
      report_date.to_date.all_month
    end

    # @return [Array<Hash>] one row per (service provider issuer, agency, resource server)
    def rows
      params = {
        month_start: month_range.begin,
        month_end: month_range.end + 1,
        now: Time.zone.now,
        superseded: SUPERSEDED,
        withdrawn: WITHDRAWN,
      }.transform_values { |value| ActiveRecord::Base.connection.quote(value) }

      sql = format(<<~SQL, params)
        SELECT
            grants.service_provider_issuer AS service_provider_issuer
          , COALESCE(agencies.name, application.friendly_name, application.issuer) AS agency
          , resource_servers.identifier AS resource_server
          , EXISTS (
              SELECT 1 FROM integrations
              WHERE integrations.issuer = COALESCE(resource_servers.billing_issuer, application.issuer)
            ) AS billing_issuer_has_agreement
          , COUNT(*) AS requested
          , COUNT(*) FILTER (
              WHERE grants.first_exchanged_at IS NULL
                AND grants.revocation_reason = %{withdrawn}
            ) AS withdrawn_before_use
          , COUNT(*) FILTER (
              WHERE grants.first_exchanged_at IS NULL
                AND grants.revocation_reason IS DISTINCT FROM %{withdrawn}
                AND (
                  grants.revoked_at IS NOT NULL
                  OR (grants.remember_until IS NOT NULL AND grants.remember_until < %{now})
                  OR (
                    grants.remember_until IS NULL
                    AND grants.rails_session_id IS DISTINCT FROM identities.rails_session_id
                  )
                )
            ) AS consented_not_exchanged
          , COUNT(*) FILTER (
              WHERE EXISTS (
                SELECT 1 FROM token_exchange_tokens tokens
                WHERE tokens.grant_id = grants.id
                  AND tokens.resource_server_id = resource_servers.id
              )
            ) AS exchanged
          , COUNT(*) FILTER (
              WHERE grants.proofed_in_session = true AND grants.first_exchanged_at IS NULL
            ) AS proofed_in_session_not_exchanged
        FROM token_exchange_grants grants
        JOIN service_providers application
          ON application.id = grants.application_service_provider_id
        JOIN token_exchange_resource_servers resource_servers
          ON resource_servers.service_provider_id = application.id
        LEFT JOIN agencies ON agencies.id = application.agency_id
        LEFT JOIN identities
          ON identities.user_id = grants.user_id
          AND identities.service_provider = grants.service_provider_issuer
        WHERE grants.consented_at >= %{month_start}::date
          AND grants.consented_at < %{month_end}::date
          AND grants.revocation_reason IS DISTINCT FROM %{superseded}
        GROUP BY
            grants.service_provider_issuer
          , COALESCE(agencies.name, application.friendly_name, application.issuer)
          , resource_servers.identifier
          -- Grouped as the two source columns (not their COALESCE) so the EXISTS above, which
          -- reads them individually, is legal under PostgreSQL's grouping rules.
          , resource_servers.billing_issuer
          , application.issuer
        ORDER BY
            grants.service_provider_issuer
          , agency
          , resource_servers.identifier
      SQL

      transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sql)
      end.to_a.map(&:symbolize_keys)
    end

    # Each delegating service provider's own billable sign-in rows for the month, split by
    # whether an exchange later excluded the row from billing.
    # @return [Array<Hash>] one row per service provider issuer
    def sign_in_rows
      params = {
        month_start: month_range.begin,
        month_end: month_range.end + 1,
        direct: SpReturnLog::ACCESS_TYPE_DIRECT,
      }.transform_values { |value| ActiveRecord::Base.connection.quote(value) }

      sql = format(<<~SQL, params)
        SELECT
            sp_return_logs.issuer AS service_provider_issuer
          , COUNT(*) FILTER (
              WHERE #{SpReturnLogBillingAdjustment.not_excluded_sql}
            ) AS billed
          , COUNT(*) FILTER (
              WHERE NOT #{SpReturnLogBillingAdjustment.not_excluded_sql}
            ) AS waived
        FROM sp_return_logs
        JOIN service_providers
          ON service_providers.issuer = sp_return_logs.issuer
          AND service_providers.token_exchange_enabled_sp = true
        WHERE sp_return_logs.billable = true
          AND COALESCE(sp_return_logs.access_type, %{direct}) = %{direct}
          AND sp_return_logs.returned_at >= %{month_start}::date
          AND sp_return_logs.returned_at < %{month_end}::date
        GROUP BY sp_return_logs.issuer
        ORDER BY sp_return_logs.issuer
      SQL

      transaction_with_timeout do
        ActiveRecord::Base.connection.execute(sql)
      end.to_a.map(&:symbolize_keys)
    end

    private

    def email_report(table, sign_ins_table)
      emails = IdentityConfig.store.delegation_outcomes_report_emails
      return if emails.blank?

      month = month_range.begin.strftime('%B %Y')
      ReportMailer.tables_report(
        to: emails,
        subject: "Delegation outcomes report - #{month}",
        message: "Report: #{REPORT_NAME}",
        reports: [
          Reporting::EmailableReport.new(
            title: "Delegated access outcomes, #{month}",
            table:,
            filename: REPORT_NAME,
          ),
          Reporting::EmailableReport.new(
            title: "Delegating service provider sign-ins, #{month}",
            table: sign_ins_table,
            filename: SIGN_INS_REPORT_NAME,
          ),
        ],
        attachment_format: :csv,
      ).deliver_now
    end

    def to_csv(table)
      CSV.generate do |csv|
        table.each { |row| csv << row }
      end
    end
  end
end
