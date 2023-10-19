# frozen_string_literal: true

module Reporting
  class TotalUserCountReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def total_user_count_report
      [
        ['All-time user count', total_user_count],
        ['Total verified users', verified_user_count],
        ['Total annual users', annual_total_user_count],
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

    def total_user_count
      Reports::BaseReport.transaction_with_timeout do
        User.where('created_at <= ?', report_date).count
      end
    end

    def verified_user_count
      Reports::BaseReport.transaction_with_timeout do
        Profile.where(active: true).where('activated_at <= ?', report_date).count
      end
    end

    def annual_total_user_count
      Reports::BaseReport.transaction_with_timeout do
        User.where(created_at: annual_start_date..end_date).count
      end
    end

    def annual_start_date
      (report_date - 1.year).beginning_of_day
    end

    def end_date
      report_date.beginning_of_day
    end
  end
end
