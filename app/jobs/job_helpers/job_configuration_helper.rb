# frozen_string_literal: true

module JobHelpers
  module JobConfigurationHelper
    module_function

    def report_receiver_based_on_cadence(report_date = Time.zone.yesterday.end_of_day,
                                         cadence = :monthly)
      report_receiver = :internal

      case cadence
      when :monthly
        report_receiver = :both if report_date.next_day.day == 1

      when :quarterly
        if [1, 4, 7, 10].include?(report_date.next_day.month) && report_date.next_day.day == 1
          report_receiver = :both
        end
      end

      report_receiver
    end

    def build_irs_report_args(report_date = Time.zone.yesterday.end_of_day, cadence = :monthly)
      report_receiver = report_receiver_based_on_cadence(report_date, cadence)
      [report_date, report_receiver]
    end
  end
end
