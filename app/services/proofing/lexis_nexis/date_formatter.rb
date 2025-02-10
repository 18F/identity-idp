# frozen_string_literal: true

module Proofing
  module LexisNexis
    class DateFormatter
      attr_reader :date

      def initialize(date_string)
        @date = Date.parse(date_string)
      end

      def formatted_date
        {
          Year: date.year.to_s,
          Month: date.month.to_s,
          Day: date.day.to_s,
        }
      end
    end
  end
end
