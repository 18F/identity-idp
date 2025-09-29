# frozen_string_literal: true

## Note: IrsCredentialTenureReport report is not currently used.

module Reporting
  class IrsCredentialTenureReport
    attr_reader :report_date, :issuers

    def initialize(report_date = Time.zone.today, issuers: [])
      @report_date = report_date
      @issuers = issuers
    end

    def time_range
      start_of_month = report_date.beginning_of_month.beginning_of_day
      end_of_month = report_date.end_of_month.end_of_day
      start_of_month..end_of_month
    end

    def irs_credential_tenure_report_definition
      table = []
      table << ['Metric', 'Definition']
      table << ['Credential Tenure', 'The average age, in months, of all accounts']
    end

    def irs_credential_tenure_report_overview
      table = []
      table << ['Report Timeframe', "#{time_range.begin.to_date} to #{time_range.end.to_date}"]
      table << ['Report Generated', Time.zone.today.to_s]
      table << ['Issuer', issuers.join(', ')]
    end

    def irs_credential_tenure_report
      table = []
      table << ['Metric', 'Value']
      table << ['Total Users', total_user_count]
      table << ['Credential Tenure', average_credential_tenure_months]
      table
    end

    def credential_tenure_emailable_report
      EmailableReport.new(
        title: 'IRS Credential Tenure Metric',
        table: irs_credential_tenure_report,
        filename: 'Credential_Tenure_Metric',
      )
    end

    def irs_credential_tenure_definition
      EmailableReport.new(
        title: 'Definitions',
        table: irs_credential_tenure_report_definition,
        filename: 'Definitions',
      )
    end

    def irs_credential_tenure_overview
      EmailableReport.new(
        title: 'Overview',
        table: irs_credential_tenure_report_overview,
        filename: 'Overview',
      )
    end

      private

    def total_user_count
      Reports::BaseReport.transaction_with_timeout do
        User.joins(:identities)
          .where(identities: { service_provider: issuers, deleted_at: nil })
          .distinct
          .count
      end
    end

    def average_credential_tenure_months
      end_of_month = report_date.end_of_month
      Reports::BaseReport.transaction_with_timeout do
        average_months = User
          .where(
            '(users.confirmed_at <= :end_of_month AND users.suspended_at IS NULL)
          OR (users.suspended_at IS NOT NULL AND users.reinstated_at IS NOT NULL)',
            end_of_month: end_of_month,
          ).where(
            'EXISTS (
            SELECT 1 FROM identities
            WHERE identities.user_id = users.id
            AND identities.service_provider IN (:issuers)
            AND identities.deleted_at IS NULL
          )',
            issuers: issuers,
          ).pick(
            Arel.sql(
              'AVG(
            EXTRACT(YEAR FROM age(?, users.confirmed_at)) * 12 +
            EXTRACT(MONTH FROM age(?, users.confirmed_at)) +
            EXTRACT(DAY FROM age(?, users.confirmed_at)) / 30.0
          )',
              end_of_month, end_of_month, end_of_month
            ),
          ).to_f.round(2)
        return average_months
      end
    end
    end
end
