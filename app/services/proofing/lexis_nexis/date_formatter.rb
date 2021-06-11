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
        if date_string =~ /\A\d{8}\z/
          Date.strptime(date_string, '%Y%m%d')
        elsif date_string =~ %r{\A\d{2}/\d{2}/\d{4}\z}
          Date.strptime(date_string, '%m/%d/%Y')
        end
      end
    end
  end
end
