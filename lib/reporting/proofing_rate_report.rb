# frozen_string_literal: true

require 'csv'
require 'reporting/identity_verification_report'

module Reporting
  class ProofingRateReport
    DATE_INTERVALS = [30, 60, 90].freeze

    attr_reader :start_date

    def initialize(start_date:)
      @start_date = start_date
    end

    # rubocop:disable Layout/LineLength
    def as_csv
      csv = []

      csv << ['Metric', *DATE_INTERVALS.map { |days| "Trailing #{days}d" }]

      csv << ['Start Date', *reports.map(&:time_range).map(&:begin)]
      csv << ['End Date', *reports.map(&:time_range).map(&:end)]

      csv << ['IDV Started', *reports.map(&:idv_started)]
      csv << ['Welcome Submitted', *reports.map(&:idv_doc_auth_welcome_submitted)]
      csv << ['Image Submitted', *reports.map(&:idv_doc_auth_image_vendor_submitted)]
      csv << ['Successfully Verified', *reports.map(&:successfully_verified_users)]

      csv << ['Blanket Proofing Rate (IDV Started to Successfully Verified)', *blanket_proofing_rates(reports)]
      csv << ['Intent Proofing Rate (Welcome Submitted to Successfully Verified)', *intent_proofing_rates(reports)]
      csv << ['Actual Proofing Rate (Image Submitted to Successfully Verified)', *actual_proofing_rates(reports)]

      csv
    end
    # rubocop:enable Layout/LineLength

    def to_csv
      CSV.generate do |csv|
        as_csv.each do |row|
          csv << row
        end
      end
    end

    def reports
      @reports ||= DATE_INTERVALS.map do |interval|
        Reporting::IdentityVerificationReport.new(
          issuers: nil, # all issuers
          time_range: (start_date - interval.days)..start_date,
        )
      end
    end

    # @param [Array<Reporting::IdentityVerificationReport>] reports
    # @return [Array<Float>]
    def blanket_proofing_rates(reports)
      reports.map do |report|
        report.successfully_verified_users.to_f / report.idv_started
      end
    end

    # @param [Array<Reporting::IdentityVerificationReport>] reports
    # @return [Array<Float>]
    def intent_proofing_rates(reports)
      reports.map do |report|
        report.successfully_verified_users.to_f / report.idv_doc_auth_welcome_submitted
      end
    end

    # @param [Array<Reporting::IdentityVerificationReport>] reports
    # @return [Array<Float>]
    def actual_proofing_rates(reports)
      reports.map do |report|
        report.successfully_verified_users.to_f / report.idv_doc_auth_image_vendor_submitted
      end
    end
  end
end

# rubocop:disable Rails/Output
if __FILE__ == $PROGRAM_NAME
  start_date = Date.parse(ARGV.first)

  puts Reporting::ProofingRateReport.new(start_date: start_date).to_csv
end
# rubocop:enable Rails/Output
