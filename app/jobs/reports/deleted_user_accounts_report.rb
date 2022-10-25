require 'identity/hostdata'
require 'csv'

module Reports
  class DeletedUserAccountsReport < BaseReport
    REPORT_NAME = 'deleted-user-accounts-report'.freeze

    def perform(_date)
      configs = IdentityConfig.store.deleted_user_accounts_report_configs
      configs.each do |report_hash|
        name = report_hash['name']
        emails = report_hash['emails']
        issuers = report_hash['issuers']
        report = deleted_user_accounts_data_for_issuers(issuers)
        emails.each do |email|
          ReportMailer.deleted_user_accounts_report(
            email: email,
            name: name,
            issuers: issuers,
            data: report,
          ).deliver_now
        end
      end
    end

    private

    def deleted_user_accounts_data_for_issuers(issuers)
      csv = CSV.new('', row_sep: "\r\n")
      issuers.each do |issuer|
        transaction_with_timeout do
          rows = DeletedAccountsReport.call(issuer, 10_000)
          rows.each do |row|
            csv << [row['last_authenticated_at'], row['identity_uuid']]
          end
        end
      end
      csv.string
    end
  end
end
