require 'identity/hostdata'
require 'json'

module Reports
  class SpIssuerUserCountsReport < BaseReport
    REPORT_NAME = 'sp-issuer-user-counts-report'.freeze

    def perform(_date, issuer)
      user_counts = transaction_with_timeout do
        Db::Identity::SpUserCounts.with_issuer(issuer)
      end

      emails = IdentityConfig.store.sp_issuer_user_counts.emails

      emails.each do |email|
        ReportMailer.system_demand_report(
          email: email,
          issuer: user_counts['issuer'],
          total: user_counts['total'],
          ial1_total: user_counts['ial1_total'],
          ial2_total: user_counts['ial2_total'],
          name: REPORT_NAME,
        ).deliver_now
      end
    end
  end
end
