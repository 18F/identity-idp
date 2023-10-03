module Reporting
  class AccountDeletionRateReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def account_deletion_report
      table = []
      table << ['Total account deleted (last 30 days)']
      table << [deleted_accounts_count]
      table
    end

    private

    def deleted_accounts_count
      start_date = report_date - 30.days
      DeletedUser.where(user_created_at: start_date..report_date).count
    end
  end
end
