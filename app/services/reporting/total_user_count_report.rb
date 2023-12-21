# frozen_string_literal: true

module Reporting
  class TotalUserCountReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def total_user_count_report
      [
        ['Metric', 'All Users', 'Verified users', 'Time Range Start', 'Time Range End'],
        ['All-time count', total_user_count, verified_user_count, '-', report_date.to_date],
        [
          'New users count',
          new_user_count,
          new_verified_user_count,
          current_month.begin.to_date,
          current_month.end.to_date,
        ],
        [
          'Annual users count',
          annual_total_user_count,
          annual_verified_user_count,
          annual_start_date.to_date,
          annual_end_date.to_date,
        ],
      ]
    end

    def total_user_count_emailable_report
      EmailableReport.new(
        title: 'Total user counts',
        table: total_user_count_report,
        filename: 'total_user_count',
      )
    end

    private

    def new_user_count
      Reports::BaseReport.transaction_with_timeout do
        User.where(created_at: current_month).count
      end
    end

    def total_user_count
      Reports::BaseReport.transaction_with_timeout do
        User.where('created_at <= ?', end_date).count
      end
    end

    def verified_user_count
      Reports::BaseReport.transaction_with_timeout do
        Profile.where(active: true).where('activated_at <= ?', end_date).count
      end
    end

    def new_verified_user_count
      Reports::BaseReport.transaction_with_timeout do
        Profile.where(active: true).where(activated_at: current_month).count
      end
    end

    def annual_total_user_count
      Reports::BaseReport.transaction_with_timeout do
        User.where(created_at: annual_start_date..annual_end_date).count
      end
    end

    def annual_verified_user_count
      Reports::BaseReport.transaction_with_timeout do
        Profile.where(active: true).
          where(activated_at: annual_start_date..annual_end_date).
          count
      end
    end

    def annual_start_date
      CalendarService.fiscal_start_date(report_date).beginning_of_day
    end

    def annual_end_date
      CalendarService.fiscal_end_date(report_date).end_of_day
    end

    def current_month
      report_date.all_month
    end

    def end_date
      report_date.end_of_day
    end
  end
end
