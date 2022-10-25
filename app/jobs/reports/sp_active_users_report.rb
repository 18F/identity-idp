require 'identity/hostdata'

module Reports
  class SpActiveUsersReport < BaseReport
    REPORT_NAME = 'sp-active-users-report'.freeze

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
        range = reporting_range(date)
        Db::Identity::SpActiveUserCounts.call(range.begin, range.end)
      end
      save_report(REPORT_NAME, results.to_json, extension: 'json')
    end

    def start_time(time)
      if time.month == 10 && time.day == 1
        current_fiscal_start_date = fiscal_start_date(time)
        current_fiscal_start_date.change(year: current_fiscal_start_date.year - 1).beginning_of_day
      else
        fiscal_start_date(time).beginning_of_day
      end
    end

    def finish_time(time)
      if time.month == 10 && time.day == 1
        current_fiscal_end_date = fiscal_end_date(time)
        current_fiscal_end_date.change(year: current_fiscal_end_date.year - 1).end_of_day
      else
        time.end_of_day
      end
    end

    def fiscal_end_date(time)
      time.change(year: time.month >= 10 ? time.year + 1 : time.year, month: 9, day: 30).end_of_day
    end

    def reporting_range(time)
      start_time(time)..finish_time(time)
    end
  end
end
