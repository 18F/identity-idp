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

    class ReportRow
      # hash comes from Db::Identity::SpActiveUserCounts.overall
      def self.from_hash_time_range(hash:, time_range:)
        new(
          ial1: hash['total_ial1_active'],
          idv: hash['total_ial2_active'],
          time_range:,
        )
      end

      attr_reader :ial1, :idv, :time_range

      def initialize(ial1:, idv:, time_range:)
        @ial1 = ial1
        @idv = idv
        @time_range = time_range
      end

      def merge(other)
        min_range = [time_range.begin, other.time_range.begin].min
        max_range = [time_range.end, other.time_range.end].max

        self.class.new(
          ial1: ial1 + other.ial1,
          idv: idv + other.idv,
          time_range: min_range..max_range,
        )
      end

      def as_csv(title:)
        [
          title,
          ial1,
          idv,
          ial1 + idv,
          time_range.begin.to_date,
          time_range.end.to_date,
        ]
      end
    end

    private

    def generate_report
      q1, q2, q3, q4 = fiscal_year_active_users_per_quarter_cumulative

      [
        ['Active Users', 'IAL1', 'IDV', 'Total', 'Range start', 'Range end'],
        monthly_active_users.as_csv(title: 'Current month'),
        q1.as_csv(title: 'Fiscal year Q1'),
        q2.as_csv(title: 'Fiscal year Q2 cumulative'),
        q3.as_csv(title: 'Fiscal year Q3 cumulative'),
        q4.as_csv(title: 'Fiscal year Q4 cumulative'),
      ]
    end

    # @return [ReportRow]
    def monthly_active_users
      @monthly_active_users ||= Reports::BaseReport.transaction_with_timeout do
        ReportRow.from_hash_time_range(
          time_range: monthly_range,
          hash: Db::Identity::SpActiveUserCounts.overall(
            monthly_range.begin,
            monthly_range.end,
          ).first,
        )
      end
    end

    # @return [Array<ReportRow>]
    def fiscal_year_active_users_per_quarter_cumulative
      @fiscal_year_active_users_per_quarter_cumulative ||= [
        CalendarService.fiscal_start_date(report_date),
        CalendarService.fiscal_q2_start(report_date),
        CalendarService.fiscal_q3_start(report_date),
        CalendarService.fiscal_q4_start(report_date),
        CalendarService.fiscal_end_date(report_date).next_day(1),
      ].each_cons(2).map do |quarter_start, next_start|
        quarter_start.beginning_of_day..next_start.prev_day(1).end_of_day
      end.map do |quarter_range|
        Reports::BaseReport.transaction_with_timeout do
          ReportRow.from_hash_time_range(
            time_range: quarter_range,
            hash: Db::Identity::SpActiveUserCounts.overall(
              quarter_range.begin,
              quarter_range.end,
            ).first,
          )
        end
      end.yield_self do |quarters_array|
        q1, q2, q3, q4 = quarters_array

        [
          q1,
          q1.merge(q2),
          q1.merge(q2).merge(q3),
          q1.merge(q2).merge(q3).merge(q4),
        ]
      end
    end

    def monthly_range
      report_date.all_month
    end

    def fiscal_start_date
      CalendarService.fiscal_start_date(report_date)
    end

    def fiscal_end_date
      CalendarService.fiscal_end_date(report_date)
    end
  end
end
