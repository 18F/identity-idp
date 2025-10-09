# frozen_string_literal: true

module Reports
  module JobConfigurationHelper
    module_function

    def get_receiver_based_on_cadence(report_date = Time.zone.yesterday.end_of_day,
                                      cadence = :monthly)
      receiver = :internal

      case cadence
      when :monthly
        receiver = :both if report_date.next_day.day == 1

      when :quarterly
        if [1, 4, 7, 10].include?(report_date.next_day.month) && report_date.next_day.day == 1
          receiver = :both
        end
      end

      receiver
    end
  end
end
