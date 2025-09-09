# frozen_string_literal: true

module Reports
  class TestTheMonthlyIrsReport < BaseReport
    REPORT_NAME = 'test_irs_monthly_cred_metrics'

    attr_reader :report_date

    def initialize(report_date = nil, *args, **rest)
      @report_date = report_date
      super(*args, **rest)
    end

    def perform
      iaas_filtered = IaaReportingHelper.iaas.filter do |x|
        x.end_date > 90.days.ago && x.issuers.include?(my_issuer)
      end

      target_partner_accounts = IaaReportingHelper.partner_accounts.select do |pa|
        pa.partner == my_partner
      end

      combined_invoice_csv = CombinedInvoiceSupplementReportV2.new.build_csv(
        iaas_filtered,
        target_partner_accounts,
      )

      save_report('test_irs_report', combined_invoice_csv, extension: 'csv')
    end

    def my_issuer
      'urn:gov:gsa:SAML:2.0.profiles:sp:sso:SSA:mySSAsp'
      # 'DOIFOIAXpressPALPOI'
    end

    def my_partner
      'SSA'
      # 'DOI'
    end
  end
end
