require 'identity/hostdata'
require 'json'

module Reports
  class SpIssuerUserCountsReport < BaseReport

    def perform(_date)
      configs = IdentityConfig.store.sp_issuer_user_counts_report_configs

      configs.each do |report_hash|

        name = report_hash['name']
        emails = report_hash['emails']
        issuer = report_hash['issuer']
      
        binding.pry

        user_counts = Db::Identity::SpUserCounts.with_issuer(issuer)
        
        emails.each do |email|
          ReportMailer.sp_issuer_user_counts(
            email: email,
            issuer: issuer,
            total: user_counts['total'],
            ial1_total: user_counts['ial1_total'],
            ial2_total: user_counts['ial2_total'],
            name: name,
          ).deliver_now
        end
      end
    end
  end
end

# def perform(_date)
#   configs = IdentityConfig.store.deleted_user_accounts_report_configs
#   configs.each do |report_hash|
#     name = report_hash['name']
#     emails = report_hash['emails']
#     issuers = report_hash['issuers']
#     report = deleted_user_accounts_data_for_issuers(issuers)
#     emails.each do |email|
#       ReportMailer.deleted_user_accounts_report(
#         email: email,
#         name: name,
#         issuers: issuers,
#         data: report,
#       ).deliver_now
#     end
#   end
# end
