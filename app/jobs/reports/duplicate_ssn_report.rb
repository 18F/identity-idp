# frozen_string_literal: true

require 'csv'

module Reports
  class DuplicateSsnReport < BaseReport
    REPORT_NAME = 'duplicate-ssn-report'

    attr_accessor :report_date

    def perform(report_date)
      @report_date = report_date

      csv = report_body

      save_report(REPORT_NAME, csv, extension: 'csv')
    end

    def start
      report_date.beginning_of_day
    end

    def finish
      report_date.end_of_day
    end

    # @return [String]
    def report_body
      # note, this will table scan until we add an index, for a once-a-day job it may be ok
      todays_profiles = Profile.
        select(:id, :ssn_signature).
        where(active: true, activated_at: start..finish)

      todays_profile_ids = todays_profiles.map(&:id).to_set

      ssn_signatures = todays_profiles.map(&:ssn_signature).uniq

      profiles_connected_by_ssn = Profile.
        includes(:user).
        where(ssn_signature: ssn_signatures).
        to_a

      profiles_connected_by_ssn.sort_by!(&:id).reverse!

      count_by_ssn = profiles_connected_by_ssn.
        group_by(&:ssn_signature).
        transform_values(&:count)
      count_by_ssn_active = profiles_connected_by_ssn.
        select(&:active?).
        group_by(&:ssn_signature).
        transform_values(&:count)

      CSV.generate do |csv|
        csv << %w[
          new_account
          uuid
          account_created_at
          identity_verified_at
          profile_active
          ssn_fingerprint
          count_ssn_fingerprint
          count_active_ssn_fingerprint
        ]

        profiles_connected_by_ssn.each do |profile|
          ssn_count = count_by_ssn[profile.ssn_signature]
          ssn_count_active = count_by_ssn_active[profile.ssn_signature]
          next if ssn_count < 2

          csv << [
            todays_profile_ids.include?(profile.id),
            profile.user.uuid,
            profile.user.created_at.in_time_zone('UTC').iso8601,
            profile.activated_at&.in_time_zone('UTC')&.iso8601,
            profile.active,
            profile.ssn_signature,
            ssn_count,
            ssn_count_active,
          ]
        end
      end
    end
  end
end
