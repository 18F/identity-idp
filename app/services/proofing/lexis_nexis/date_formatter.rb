module Proofing
  module LexisNexis
    class DateFormatter
      attr_reader :date

      def initialize(date_string)
        @date = parse_date_string(date_string)
      end

      def formatted_date
        {
          Year: date.year.to_s,
          Month: date.month.to_s,
          Day: date.day.to_s,
        }
      end

      def yyyymmdd
        date.strftime('%Y%m%d')
      end

      private

      def parse_date_string(date_string)
        if /\A\d{8}\z/.match?(date_string)
          Date.strptime(date_string, '%Y%m%d')
        else
          DateParser.parse_legacy(date_string)
        end
      end
    end
  end
end
