# frozen_string_literal: true

module Reporting
  class TotalUserCountReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def total_user_count_report
      [
        ['All-time user count'],
        [total_user_count],
      ]
    end

    private

    def total_user_count
      User.where('created_at <= ?', report_date).count
    end
  end
end
