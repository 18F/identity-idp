require 'login_gov/hostdata'

module Reports
  class DocAuthFunnelReport < BaseReport
    REPORT_NAME = 'doc-auth-funnel-report'.freeze

    def call
      user_counts = transaction_with_timeout do
        Db::Identity::SpUserCounts.call
      end
      save_report(REPORT_NAME, user_counts.to_json)
    end
  end
end
