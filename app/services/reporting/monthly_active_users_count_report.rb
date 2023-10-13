module Reporting
  class MonthlyActiveUsersCountReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def monthly_active_users_count_report
      [
        ['Monthly Active Users', 'Value'],
        ['IAL1', total_ial1_active],
        ['IDV', total_ial2_active],
        ['Total', total_ial1_active + total_ial2_active],
      ]
    end

    def monthly_active_users_count_emailable_report
      EmailableReport.new(
        email_options: {
          title: "#{report_month_year} Active Users",
        },
        table: monthly_active_users_count_report,
        csv_name: 'monthly_active_users_count',
      )
    end

    private

    def active_users_count
      @active_users_count ||= Db::Identity::SpActiveUserCounts.overall(range.begin, range.end).first
    end

    def total_ial1_active
      active_users_count['total_ial1_active']
    end

    def total_ial2_active
      active_users_count['total_ial2_active']
    end

    def range
      @range ||= report_date.day == 1 ? report_date.last_month.all_month : report_date.all_month
    end

    def report_month_year
      "#{range.begin.strftime("%B")} #{range.begin.year}"
    end
  end
end
