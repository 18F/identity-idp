# frozen_string_literal: true

module JobHelpers
  module DelayedReportConfigurationHelper
    DATA_LAG_DAYS = 0 # 0 day lag - for this report, log replication has minimal delay
    # (For modeled data in marts tables, this lag could be a few days)

    SUPPORTED_TIME_FRAMES = %w[daily weekly monthly quarterly].freeze

    module_function

    # Decides whether a report run covers a period that has fully closed (so it
    # is safe to send to a partner) or is still in progress (internal only).
    def determine_receiver_for_period_report(
      run_date: Time.zone.now,
      lookback_days: 3,
      time_frame: 'quarterly',
      external_rule: 'external_if_period_end'
    )
      unless SUPPORTED_TIME_FRAMES.include?(time_frame.to_s)
        raise ArgumentError, "Unsupported time frame: #{time_frame}"
      end

      report_period_date = run_date - lookback_days.days
      period_end = period_end_for(report_period_date, time_frame.to_s)

      determine_receiver_for_period(period_end, external_rule)
    end

    def period_end_for(date, time_frame)
      case time_frame
      when 'daily'
        date.all_day.end
      when 'weekly'
        date.all_week(:sunday).end
      when 'monthly'
        date.all_month.end
      when 'quarterly'
        date.all_quarter.end
      else
        raise ArgumentError, "Unsupported time frame: #{time_frame}"
      end
    end

    # The comparison is strict (<), not <=, to match external_report? in
    # reporting-rails. On the final day of a period the producer still treats
    # the period as open and writes only the internal CSV, so returning :both
    # here would send a consumer looking for a latest_external_* key that does
    # not exist yet.
    def determine_receiver_for_period(period_end_date, external_rule)
      case external_rule.to_s.downcase
      when 'external_if_period_end'
        if period_end_date.to_date < Date.current - DATA_LAG_DAYS.days
          :both
        else
          :internal
        end
      when 'always_internal'
        :internal
      when 'always_external'
        :both
      else
        raise ArgumentError, "Unsupported external rule: #{external_rule}"
      end
    end
  end
end
