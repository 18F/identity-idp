module Reports
  class SpIssuerUserCountsReport < BaseReport
    REPORT_NAME = 'sp-issuer-user-counts-report'.freeze

    def perform(_date)
      configs = IdentityConfig.store.sp_issuer_user_counts_report_configs

      configs.each do |report_hash|
        emails = report_hash['emails']
        issuer = report_hash['issuer']

        user_counts = Db::Identity::SpUserCounts.with_issuer(issuer)

        emails.each do |email|
          ReportMailer.sp_issuer_user_counts_report(
            name: REPORT_NAME,
            email: email,
            issuer: issuer,
            total: user_counts['total'],
            ial1_total: user_counts['ial1_total'],
            ial2_total: user_counts['ial2_total'],
          ).deliver_now
        end
      end
    end
  end
end
