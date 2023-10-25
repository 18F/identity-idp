# frozen_string_literal: true

module Reports
  class SpIssuerUserCountsReport < BaseReport
    REPORT_NAME = 'sp-issuer-user-counts-report'

    def perform(_date)
      configs = IdentityConfig.store.sp_issuer_user_counts_report_configs

      configs.each do |report_hash|
        emails = report_hash['emails']
        issuer = report_hash['issuer']

        user_counts = transaction_with_timeout do
          Db::Identity::SpUserCounts.with_issuer(issuer)
        end

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
