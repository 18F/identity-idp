# frozen_string_literal: true

require 'csv'

module Reports
  class QuarterlyAccountStats < BaseReport
    REPORT_NAME = 'quarterly-account-stats'

    def perform(report_date)
      report = report_body(report_date - 90.days, report_date)
      save_report(REPORT_NAME, report, extension: 'csv')
    end

    def report_body(start_date, end_date)
      report = {}

      transaction_with_timeout do
        report[:start_date] = start_date.to_s
        report[:end_date] = end_date.to_s

        report[:deleted_users_all_time] = DeletedUser.count
        report[:deleted_users_for_period] = deleted_user_count(start_date:, end_date:)

        report[:users_all_time] = User.count
        report[:users_for_period] = user_count(start_date:, end_date:)

        report[:users_and_deleted_all_time] =
          report[:deleted_users_all_time] + report[:users_all_time]
        report[:users_and_deleted_for_period] =
          report[:deleted_users_for_period] + report[:users_for_period]

        report[:proofed_all_time] = Profile.where(active: true).count
        report[:proofed_for_period] = idv_user_count(start_date:, end_date:)
      end

      CSV.generate do |csv|
        csv << report.keys
        csv << report.values
      end
    end

    private

    def deleted_user_count(start_date:, end_date:)
      DeletedUser.where(user_created_at: start_date..end_date).count
    end

    def user_count(start_date:, end_date:)
      User.where(created_at: start_date..end_date).count
    end

    def idv_user_count(start_date:, end_date:)
      Profile.where(active: true).where(activated_at: start_date..end_date).count
    end
  end
end
