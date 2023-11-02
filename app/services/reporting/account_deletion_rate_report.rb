module Reporting
  class AccountDeletionRateReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def account_deletion_report
      table = []
      table << ['Deleted Users', 'Fully Registered Users', 'Deletion Rate']
      table << [deleted_user_count, fully_registered_users, deletion_rate]
      table
    end

    def account_deletion_emailable_report
      EmailableReport.new(
        title: 'Account deletion rate (last 30 days)',
        float_as_percent: true,
        precision: 4,
        table: account_deletion_report,
        filename: 'account_deletion_rate',
      )
    end

    private

    def deleted_user_count
      @deleted_user_count ||= Reports::BaseReport.transaction_with_timeout do
        DeletedUser.
          where(deleted_at: start_date..end_date).
          where('user_created_at < ?', end_date).
          count
      end
    end

    def fully_registered_users
      @fully_registered_users ||= Reports::BaseReport.transaction_with_timeout do
        RegistrationLog.where(registered_at: start_date..end_date).count
      end
    end

    def deletion_rate
      deleted_user_count.to_f / fully_registered_users.to_f
    end

    def start_date
      (report_date - 30.days).beginning_of_day
    end

    def end_date
      report_date.beginning_of_day
    end
  end
end
