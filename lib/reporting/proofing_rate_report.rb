# frozen_string_literal: true

require 'csv'
require 'reporting/identity_verification_report'

module Reporting
  class ProofingRateReport
    DATE_INTERVALS = ['30', '60', '90']

    # The basic goal here is to call IdentityVerificationReport for 30, 60, and 90 days
    # And then return some of the stuff.

    attr_accessor :ivr

    def report_for(start_date:)
      csv = []
      @ivr = {}
      DATE_INTERVALS.each do |interval|
        @ivr[interval.to_sym] = Reporting::IdentityVerificationReport.new(
          issuers: nil, # all issuers
          time_range: (start_date - interval.days)..start_date,
        )
      end

      csv << ['PROOFING RATES', 'Trailing 30d', 'Trailing 60d', 'Trailing 90d']
      csv << ['Blanket Proofing Rate ', *blanket_proofing_rates]
      csv << ['Intent Proofing Rate ', *intent_proofing_rates]
      csv << ['Actual Proofing Rate ', *actual_proofing_rates]
      # csv << ['Industry Proofing Rate', 'FIXME']
      csv << []
      # Two additional queries:
      # 1. How many users started IDV and reached IPP / GPO / fraud review?
      # 2. How many users started IDV and were rejected from moving forward, due to “fraud”?
      # marked_as_fraudulent should be #2, also used in Industry Proofing Rate
    end

    def blanket_proofing_rates
      blanket_rates = []
      DATE_INTERVALS.each do |interval|
        user_stats = ivr[interval.to_sym]
        blanket_rates << "#{
          user_stats.idv_started.to_f / user_stats.successfully_verified_users
        }%"
      end
      blanket_rates
    end

    def intent_proofing_rates
      intent_rates = []
      DATE_INTERVALS.each do |interval|
        user_stats = ivr[interval.to_sym]
        intent_rates << "#{
          user_stats.idv_doc_auth_welcome_submitted.to_f / user_stats.successfully_verified_users
        }%"
      end
      intent_rates
    end

    def actual_proofing_rates
      actual_rates = []
      DATE_INTERVALS.each do |interval|
        user_stats = ivr[interval.to_sym]
        actual_rates << "#{
          user_stats.idv_doc_auth_image_vendor_submitted.to_f / user_stats.successfully_verified_users
        }%"
      end
      actual_rates
    end
  end
end
