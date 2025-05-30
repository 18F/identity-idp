# frozen_string_literal: true

module Reporting
  class IrsCredentialTenureReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def irs_credential_tenure_report_definition
      table = []
      table << ['Metric', 'Definition']
      table << ['Credential Tenure", "The average age, in months, of all accounts']
    end

    def irs_credential_tenure_report_report
      table = []
      table << ['Metric', 'Value']
      table << ['Total Users', total_user_count]
      table << ['Credential Tenure', average_credential_tenure_months]
      table
    end

    def credential_tenure_emailable_report
      EmailableReport.new(
        title: 'IRS Credential Tenure Metric',
        table: irs_credential_tenure_report_report,
        filename: 'Credential_Tenure_Metric',
      )
    end

    def irs_credential_tenure_definition
      EmailableReport.new(
        title: 'Definitions',
        table: irs_credential_tenure_report_definition,
        # filename: 'Definitions',
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
      users = User.where('created_at <= ?', end_of_month)
      return 0 if users.count == 0

      total_months = users.sum do |user|
        (end_of_month.year * 12 + end_of_month.month) -
          (user.created_at.year * 12 + user.created_at.month)
      end
      (total_months.to_f / users.count).round(2)
    end
    end
end
