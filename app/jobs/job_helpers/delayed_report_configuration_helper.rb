# frozen_string_literal: true

module JobHelpers
  module DelayedReportConfigurationHelper
    module_function

    # This helper is meant to return the end date for a recent quarter, month, week or day
    # It also has logic to determine if a report should be internal or external given that
    # ending date. It was built to enable sending monthly reports externally only
    # if it is the end of a quarter
    def determine_end_date_for_time_period_and_receiver(
      starting_date: Time.zone.today,
      go_backwards_to_most_recent: 'month',
      external_rule: 'external_if_quarter_end'
    )
      raise ArgumentError, 'starting_date cannot be nil' unless starting_date

      end_date = calculate_end_date_for_previous_period(
        starting_date,
        go_backwards_to_most_recent,
      )

      receiver = determine_receiver(end_date, external_rule)

      [end_date, receiver]
    end

    private

    def calculate_end_date_for_previous_period(starting_date, period_type)
      case period_type.to_s.downcase
      when 'month'
        # Go back to end of most recent complete month
        starting_date.beginning_of_month.prev_day.end_of_day
      when 'quarter'
        # Go back to end of most recent complete quarter
        starting_date.beginning_of_quarter.prev_day.end_of_day
      when 'week'
        # Go back to end of most recent complete week (Sunday)
        starting_date.beginning_of_week.prev_day.end_of_day
      when 'day'
        # Go back to end of previous day
        starting_date.prev_day.end_of_day
      else
        raise ArgumentError, "Unsupported period type: #{period_type}"
      end
    end

    def determine_receiver(end_date, external_rule)
      case external_rule.to_s.downcase
      when 'external_if_quarter_end'
        # Send external if this date is also the end of a quarter
        if end_date.end_of_quarter.to_date == end_date.to_date
          :both
        else
          :internal
        end
      when 'external_if_year_end'
        # Send external if this date is also the end of a year
        if end_date.end_of_year.to_date == end_date.to_date
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
