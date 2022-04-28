require 'identity/hostdata'
require 'csv'

module Reports
  class SpActiveUsersReport < BaseReport
    REPORT_NAME = 'sp-active-users-report'.freeze

    include GoodJob::ActiveJobExtensions::Concurrency

    good_job_control_concurrency_with(
      total_limit: 1,
      key: -> { "#{REPORT_NAME}-#{arguments.first.to_date}" },
    )

    # This daily job captures the total number of active users per SP from the beginning of the the
    # current fiscal year until now.
    #
    # A fiscal year is from October 1st 12:00:00AM to September 30th 11:59:59PM the following year.
    #
    # To provide a report that captures the total number of active users for an entire fiscal year
    # and avoids reporting partial days, October 1st is treated differently.
    # The report will run for the entire fiscal year that ended the day before rather than for the
    # partial day of October 1st in the current fiscal year.
    def perform(date)
      results = transaction_with_timeout do
        Db::Identity::SpActiveUserCounts.call(start_time(date), finish_time(date))
      end
      save_report(REPORT_NAME, to_csv(results), extension: 'csv')
    end

    def start_time(time)
      if time.month == 10 && time.day == 1
        fiscal_start_date(time).change(year: fiscal_start_date.year - 2).beginning_of_day
      else
        fiscal_start_date(time)
      end
    end

    def finish_time(time)
      if time.month == 10 && time.day == 1
        fiscal_end_date(time)
      else
        time.end_of_day
      end
    end

    def fiscal_end_date(time)
      time.change(year: time.month >= 10 ? time.year : time.year + 1, month: 9, day: 30).end_of_day
    end

    def to_csv(results)
      CSV.generate do |csv|
        csv << %w[
          issuer
          app_id
          total_ial1_active
          total_ial2_active
        ]

        results.each do |row|
          csv << row.values_at('issuer', 'app_id', 'total_ial1_active', 'total_ial2_active')
        end
      end
    end
  end
end
