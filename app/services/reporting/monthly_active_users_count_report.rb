module Reporting
  class MonthlyActiveUsersCountReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def monthly_active_users_count_report
      [
        ['Monthly IAL1 Active', 'Monthly IAL2 Active', 'Total'],
        [total_ial1_active, total_ial2_active, total_ial1_active + total_ial2_active],
      ]
    end

    def monthly_active_users_count_emailable_report
      EmailableReport.new(
        email_options: {
          title: 'Monthly active user count',
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
      report_date.day == 1 ? report_date.last_month.all_month : report_date.all_month
    end
  end
end
