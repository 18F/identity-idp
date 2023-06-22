# frozen_string_literal: true
require 'csv'

module Reports
  class QuarterlyAccountStats < BaseReport
    REPORT_NAME = 'quarterly-account-stats'

    # put this in job_configurations.rb

    def perform(report_date)
      report = report_body(report_date - 90.days, report_date)
      puts report
      # call save_report
    end

    def report_body(start_date, end_date)
      report = {}

      report[:start_date] = start_date.to_s
      report[:end_date] = end_date.to_s

      report[:deleted_users_all_time] = deleted_user_count
      report[:deleted_users_for_period] = deleted_user_count(start_date:, end_date:)

      report[:users_all_time] = user_count
      report[:users_for_period] = user_count(start_date:, end_date:)

      report[:proofed_all_time] = idv_user_count
      report[:proofed_for_period] = idv_user_count(start_date:, end_date:)

      CSV.generate do |csv|
        csv << report.keys
        csv << report.values
      end
    end

    private

    # MAW: The all-time ones can probably look at cardinality and not need
    # transaction_with_timeout, but might as well do it anyway?
    def deleted_user_count(start_date: nil, end_date: nil)
      if !start_date && !end_date
        transaction_with_timeout do
          DeletedUser.count
        end
      else
        transaction_with_timeout do
          DeletedUser.where(
            'user_created_at >= ? and user_created_at < ?',
            start_date,
            end_date
          ).count
        end
      end
    end

    def user_count(start_date: nil, end_date: nil)
      if !start_date && !end_date
        transaction_with_timeout do
          User.count
        end
      else
        User.where(
          'created_at >= ? and created_at < ?',
          start_date,
          end_date
        ).count
      end
    end

    def idv_user_count(start_date: nil, end_date: nil)
      if !start_date && !end_date
        transaction_with_timeout do
          Profile.where(active: true).count
        end
      else
        transaction_with_timeout do
          Profile.where(active: true).where(
            'activated_at >= ? and activated_at < ?',
            start_date,
            end_date
          ).count
        end
      end
    end
  end
end
