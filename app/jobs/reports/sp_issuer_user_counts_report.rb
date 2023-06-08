require 'identity/hostdata'
require 'json'

module Reports
  class SpIssuerUserCountsReport < BaseReport
    REPORT_NAME = 'sp-issuer-user-counts-report'.freeze

    # [{"issuer"=>"urn:gov:opm:openidconnect.profiles:sp:sso:ServicesOnline:SOL",
    # "total"=>1238252,
    # "ial1_total"=>1238252,
    # "ial2_total"=>0,
    # "app_id"=>"LGZ317"}]

    def perform(_date, issuer)
      user_counts = transaction_with_timeout do
        Db::Identity::SpUserCounts.with_issuer(issuer)
      end

      user_counts_json = JSON.parse(user_counts.to_json)
      issuer = user_counts_json['issuer']
      total = user_counts_json['total']
      ial1_total = user_counts_json['ial1_total']
      ial2_total = user_counts_json['ial2_total']
     

      emails = IdentityConfig.store.sp_issuer_user_counts.emails

      emails.each do |email|
          ReportMailer.system_demand_report(
            email: email,
            issuer: issuer,
            total: total,
            ial1_total: ial1_total,
            ial2_total: ial2_total,
            name: REPORT_NAME,
          ).deliver_now
      end
    end
  end
end
