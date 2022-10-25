require 'identity/hostdata'

module Reports
  class OmbFitaraReport < BaseReport
    OLDEST_TIMESTAMP = '2016-01-01 00:00:00'.freeze
    MOST_RECENT_MONTHS_COUNT = 2
    REPORT_NAME = 'omb-fitara-report'.freeze

    def perform(_date)
      results = transaction_with_timeout do
        report_hash
      end
      save_report(REPORT_NAME, results.to_json, extension: 'json')
    end

    private

    def report_hash
      month, year = current_month
      counts = []
      MOST_RECENT_MONTHS_COUNT.times do
        counts << { month: "#{year}#{format('%02d', month)}", count: count_for_month(month, year) }
        month, year = previous_month(month, year)
      end
      { counts: counts }
    end

    def count_for_month(month, year)
      month, year = next_month(month, year)
      finish = "#{year}-#{month}-01 00:00:00"
      Funnel::Registration::RangeRegisteredCount.call(OLDEST_TIMESTAMP, finish)
    end

    def current_month
      today = Time.zone.today
      [today.strftime('%m').to_i, today.strftime('%Y').to_i]
    end

    def next_month(month, year)
      month += 1
      if month > 12
        month = 1
        year += 1
      end
      [month, year]
    end

    def previous_month(month, year)
      month -= 1
      if month.zero?
        month = 12
        year -= 1
      end
      [month, year]
    end
  end
end
