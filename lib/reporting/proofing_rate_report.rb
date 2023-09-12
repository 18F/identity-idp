# frozen_string_literal: true

require 'csv'
require 'reporting/identity_verification_report'

module Reporting
  class ProofingRateReport
    DATE_INTERVALS = [30, 60, 90]

    # The basic goal here is to call IdentityVerificationReport for 30, 60, and 90 days
    # And then return some of the stuff.

    attr_accessor :ivr

    def report_for(start_date:)
      @ivr = Reporting::IdentityVerificationReport.new(
        issuers: nil, # all issuers
        # FIXME: We actually want to loop over DATE_INVERVALS but it's
        # easier to start with one and then add that in.
        time_range: (start_date - 30.days)..start_date,
      )

      csv = []

      csv << ['Blanket Proofing Rate', blanket_proofing_rate]
      csv << ['Intent Proofing Rate', intent_proofing_rate]
      csv << ['Actual Proofing Rate', actual_proofing_rate]
      csv << ['Industry Proofing Rate', 'FIXME']
      csv << []
      # Two additional queries:
      # 1. How many users started IDV and reached IPP / GPO / fraud review?
      # 2. How many users started IDV and were rejected from moving forward, due to “fraud”?
      # marked_as_fraudulent should be #2, also used in Industry Proofing Rate
    end

    def blanket_proofing_rate
      ivr.idv_started / ivr.successfully_verified_users
    end

    def intent_proofing_rate
      ivr.idv_doc_auth_welcome_submitted / ivr.successfully_verified_users
    end

    def actual_proofing_rate
      ivr.idv_doc_auth_image_vendor_submitted / ivr.successfully_verified_users
    end

    def marked_as_fraudulent
      # flagged by ThreatMetrix and not then given redress
      # or
      # rejected by Acuant as having suspicious evidence that does not then successfully verify
      # 'IdV: Not verified visited'
      # Or, look at 'IdV: review complete' and is fraud_rejection boolean
      # 'Fraud: Automatic Fraud Rejection'
    end

    def abandon_the_process
      # not marked_as_fraudulent (just subtract that)
      #  is not blocked by us (e.g. is stopped in funnel w/ 
      #  rejection codes by Acuant/InstantVerify/PhoneFinder/USPS)
      # I think we need to return (total - sum of all those "not..." cases)
    end
  end
end
