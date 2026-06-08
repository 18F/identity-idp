# frozen_string_literal: true

module JobHelpers
  module DelayedReportConfigurationHelper
    DATA_LAG_DAYS = 0 # 0 day lag - for this report, log replication has minimal delay
    # (For modeled data in marts tables, this lag could be a few days)

    module_function

    def determine_receiver_for_demographics_report(
      run_date: Time.zone.now,
      lookback_days: 3,
      external_rule: 'external_if_quarter_end'
    )
      # Figure out what reporting period we're covering
      report_period_date = run_date - lookback_days.days
      quarter_end = report_period_date.all_quarter.end

      # Determine receiver based on rule
      determine_receiver_for_period(quarter_end, external_rule)
    end

    private

    def determine_receiver_for_period(quarter_end_date, external_rule)
      case external_rule.to_s.downcase
      when 'external_if_quarter_end'
        # Send external if we're past the quarter end + reasonable lag
        if quarter_end_date.to_date <= Date.current - DATA_LAG_DAYS.days
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
