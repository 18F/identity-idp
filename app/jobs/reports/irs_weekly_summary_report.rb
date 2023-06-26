require 'csv'

module Reports
  class IrsWeeklySummaryReport < BaseReport
    attr_reader :report_date
    REPORT_NAME = 'irs-weekly-summary-report'

    def perform(report_date)
      @name = REPORT_NAME
      @report_date = report_date

      email = IdentityConfig.store.system_demand_report_email
      ReportMailer.system_demand_report(
        email: email,
        data: generate_csv,
        name: REPORT_NAME,
      ).deliver_now

      # save report has a predefined bucket where things get saved
      # upload_file_to_s3_bucket can be used to define specific buckets (ie. public/private)
      save_report(
        REPORT_NAME,
        generate_csv,
        extension: 'csv',
      )
    end

    private

    # The total number of users registered with Login.gov
    def query_system_demand
      User.where('created_at <= ?', report_date.beginning_of_day).count
    end

    def generate_csv
      CSV.generate do |csv|
        csv << [
          'Data Requested',
          'Total Count',
        ]
        csv << [
          'System Demand',
          query_system_demand,
        ]
      end
    end
  end
end
