module Reporting
  class ActiveUsersCountReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def active_users_count_emailable_report
      EmailableReport.new(
        title: 'Active Users',
        table: generate_report,
        filename: 'active_users_count',
      )
    end

    def generate_report
      [
        ['Active Users', 'IAL1', 'IDV', 'Total', 'Range start', 'Range end'],
        current_month_row,
        fiscal_year_row,
      ]
    end

    private

    def current_month_row
      [
        "Monthly #{report_month_year}",
        monthly_ial1,
        monthly_ial2,
        monthly_total,
        monthly_range.begin,
        monthly_range.end,
      ]
    end

    def fiscal_year_row
      [
        "Fiscal Year #{fiscal_end_date.year}",
        fiscal_year_ial1,
        fiscal_year_ial2,
        fiscal_total,
        fiscal_start_date,
        fiscal_end_date,
      ]
    end

    def monthly_ial1
      monthly_active_users['total_ial1_active']
    end

    def monthly_ial2
      monthly_active_users['total_ial2_active']
    end

    def monthly_total
      monthly_ial1 + monthly_ial2
    end

    def fiscal_year_ial1
      fiscal_year_active_users['total_ial1_active']
    end

    def fiscal_year_ial2
      fiscal_year_active_users['total_ial2_active']
    end

    def fiscal_total
      fiscal_year_ial1 + fiscal_year_ial2
    end

    def monthly_active_users
      @monthly_active_users ||= Reports::BaseReport.transaction_with_timeout do
        Db::Identity::SpActiveUserCounts.overall(monthly_range.begin, monthly_range.end).first
      end
    end

    def fiscal_year_active_users
      @fiscal_year_active_users ||= Reports::BaseReport.transaction_with_timeout do
        Db::Identity::SpActiveUserCounts.overall(fiscal_start_date.beginning_of_day, fiscal_end_date.end_of_day).first
      end
    end

    def monthly_range
      report_date.day == 1 ? report_date.last_month.all_month : report_date.all_month
    end

    def fiscal_start_date
      CalendarService.fiscal_start_date(report_date)
    end

    def fiscal_end_date
      CalendarService.fiscal_end_date(report_date)
    end

    def report_month_year
      "#{monthly_range.begin.strftime("%B")} #{monthly_range.begin.year}"
    end
  end
end
