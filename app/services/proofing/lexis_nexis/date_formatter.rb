module Proofing
  module LexisNexis
    class DateFormatter
      attr_reader :date

      def initialize(date_string)
        # Can switch to Date.parse after next deploy
        @date = DateParser.parse_legacy(date_string)
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
