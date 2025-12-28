# frozen_string_literal: true

module Proofing
  module LexisNexis
    class DateFormatter
      attr_reader :date

      def initialize(date_string, rdp_version: :rdp_v2)
        @date = Date.parse(date_string)
        @rdp_version = rdp_version
      end

      def formatted_date
        case @rdp_version
        when :rdp_v3
          v3_formatted_date
        else
          v2_formatted_date
        end
      end

      def v2_formatted_date
        {
          Year: date.year.to_s,
          Month: date.month.to_s,
          Day: date.day.to_s,
        }
      end

      def v3_formatted_date
        {
          Year: date.year,
          Month: date.month,
          Day: date.day,
        }
      end
    end
  end
end
