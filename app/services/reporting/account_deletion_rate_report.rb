module Reporting
  class AccountDeletionRateReport
    attr_reader :report_date

    def initialize(report_date = Time.zone.today)
      @report_date = report_date
    end

    def account_deletion_report
      table = []
      table << ['Deleted Users', 'Total Users', 'Deletion Rate']
      table << [deleted_user_count, users_and_deleted_for_period, deletion_rate]
      table
    end

    def account_deletion_emailable_report
      EmailableReport.new(
        email_options: {
          title: 'Account deletion rate (last 30 days)',
          float_as_percent: true,
          precision: 4,
        },
        table: account_deletion_report,
        csv_name: 'account_deletion_rate',
      )
    end

    private

    def deleted_user_count
      @deleted_user_count ||= DeletedUser.where(user_created_at: start_date..end_date).count
    end

    def user_count
      @user_count ||= User.where(created_at: start_date..end_date).count
    end

    def users_and_deleted_for_period
      deleted_user_count + user_count
    end

    def deletion_rate
      deleted_user_count.to_f / users_and_deleted_for_period.to_f
    end

    def start_date
      (report_date - 30.days).beginning_of_day
    end

    def end_date
      report_date.beginning_of_day
    end
  end
end
