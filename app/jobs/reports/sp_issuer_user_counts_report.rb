module Reports
  class SpIssuerUserCountsReport < BaseReport
    REPORT_NAME = 'sp-issuer-user-counts-report'.freeze

    def perform(_date)
      configs = IdentityConfig.store.sp_issuer_user_counts_report_configs
      message = "Report: #{REPORT_NAME}"
      subject = 'Service provider user count report'

      configs.each do |report_hash|
        emails = report_hash['emails']
        issuer = report_hash['issuer']

        user_counts = transaction_with_timeout do
          Db::Identity::SpUserCounts.with_issuer(issuer)
        end

        reports = [
          Reporting::EmailableReport.new(
            title: 'Overview',
            table: overview_table(issuer),
          ),
          Reporting::EmailableReport.new(
            title: 'User counts',
            table: user_table(user_counts),
          ),
        ]

        emails.each do |email|
          ReportMailer.tables_report(
            email:,
            subject:,
            message:,
            reports:,
            attachment_format: :csv,
          ).deliver_now
        end
      end
    end

    def overview_table(issuer)
      [
        ['Report Generated', Time.zone.today.to_s],
        ['Issuer', issuer],
      ]
    end

    def user_table(user_counts)
      [
        ['Metric', 'Number of users'],
        ['Total Users', user_counts['total']],
        ['IAL1 Users', user_counts['ial1_total']],
        ['Identity Verified Users', user_counts['ial2_total']],
      ]
    end
  end
end
