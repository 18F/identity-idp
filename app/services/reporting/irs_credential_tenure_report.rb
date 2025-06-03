# frozen_string_literal: true

module Reporting
  class IrsCredentialTenureReport
    attr_reader :report_date, :issuers

    def initialize(report_date = Time.zone.today, issuers: [])
      @report_date = report_date
      @issuers = issuers
    end

    def time_range
      today = Time.zone.today
      last_sunday = today.beginning_of_week(:sunday) - 7.days
      last_saturday = last_sunday + 6.days

      last_sunday.beginning_of_day..last_saturday.end_of_day
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
        User.count
      end
    end

    def average_credential_tenure_months
      end_of_month = report_date.end_of_month
      users = User.joins(:identities)
        .where('created_at <= ?', end_of_month)
        .where(identities: { service_provider: issuers, deleted_at: nil })
        .distinct
      return 0 if users.count == 0

      total_months = users.sum do |user|
        ((end_of_month.to_date - user.created_at.to_date).to_f / 30)
      end
      (total_months.to_f / users.count).round(2)
    end
    end
end
