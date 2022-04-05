require 'csv'

module Agreements
  module Reports
    class IntegrationUsageReport < BaseReport
      def self.run(**params)
        new(**params).run
      end

      def initialize(issuer:, start_date:, end_date:, output:)
        @issuer = issuer
        validate_issuer
        @start_date = parse_date(start_date)
        @end_date = parse_date(end_date)
        validate_dates
        @output = output
        validate_output
        @usage = empty_daily_usage_hash
      end

      def run
        transaction_with_timeout do
          Agreements::Db::SpReturnLogScan.call do |return_log|
            @usage.transform_values! { |daily_result| daily_result.update(return_log) }
          end
        end

        save_csv(usage)
      end

      private

      CSV_HEADER = %w[
        date
        ial1_requests
        ial2_requests
        ial1_responses
        ial2_responses
        unique_users
      ].freeze

      attr_reader :issuer, :start_date, :end_date, :output, :usage

      def validate_issuer
        return if ServiceProvider.find_by(issuer: issuer).present?

        raise ArgumentError.new('The issuer must correspond to a service provider')
      end

      def parse_date(date_str)
        Date.parse(date_str)
      end

      def validate_dates
        return unless end_date < start_date

        raise ArgumentError.new('The end date cannot be before the start date')
      end

      def validate_output
        return unless File.exist?(@output)

        raise ArgumentError.new('Output file already exists')
      end

      def empty_daily_usage_hash
        (start_date..end_date).each_with_object({}) do |date, hash|
          hash[date] = Agreements::DailyUsage.new(date)
        end
      end

      def save_csv(results)
        CSV.open(output, 'w') do |csv|
          csv << CSV_HEADER

          results.each do |date, usage|
            csv << [
              date.strftime('%Y-%m-%d'),
              usage.ial1_requests,
              usage.ial2_requests,
              usage.ial1_responses,
              usage.ial2_responses,
              usage.unique_users.length,
            ]
          end
        end
      end
    end
  end
end
