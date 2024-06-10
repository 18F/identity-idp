# frozen_string_literal: true

module Db
  module MonthlySpAuthCount
    module NewUniqueMonthlyUserCountsByPartner
      extend Reports::QueryHelpers

      UserVerifiedKey = Data.define(:user_id, :profile_verified_at, :profile_age).freeze

      module_function

      # @param [String] partner label for billing (Partner requesting agency)
      # @param [Array<String>] issuers issuers for the iaa
      # @param [Date] start_date iaa start date
      # @param [Date] end_date iaa end date
      # @return [PG::Result, Array]
      def call(partner:, issuers:, start_date:, end_date:)
        date_range = start_date...end_date if start_date.present? && end_date.present?

        return [] if !date_range || issuers.blank?

        # Query a month at a time, to keep query time/result size fairly reasonable
        months = Reports::MonthHelper.months(date_range)
        queries = build_queries(issuers: issuers, months: months)

        year_month_to_users_to_profile_age = Hash.new do |ym_h, ym_k|
          ym_h[ym_k] = {}
        end

        queries.each do |query|
          temp_copy = year_month_to_users_to_profile_age.deep_dup

          with_retries(
            max_tries: 3,
            rescue: [
              ActiveRecord::SerializationFailure,
              PG::ConnectionBad,
              PG::TRSerializationFailure,
              PG::UnableToSend,
            ],
            handler: proc do
              year_month_to_users_to_profile_age = temp_copy
              ActiveRecord::Base.connection.reconnect!
            end,
          ) do
            Reports::BaseReport.transaction_with_timeout do
              ActiveRecord::Base.connection.execute(query).each do |row|
                year_month = row['year_month']
                profile_age = row['profile_age']
                user_id = row['user_id']
                profile_verified_at = row['profile_verified_at']

                user_unique_id = UserVerifiedKey.new(user_id:, profile_verified_at:, profile_age:)

                year_month_to_users_to_profile_age[year_month][user_unique_id] = profile_age
              end
            end
          end
        end
        rows = []

        prev_seen_user_proofed_events = Set.new
        issuers_set = issuers.to_set
        year_months = year_month_to_users_to_profile_age.keys.sort

        # rubocop:disable Metrics/BlockLength
        year_months.each do |year_month|
          users_to_profile_age = year_month_to_users_to_profile_age[year_month]

          this_month_user_proofed_events = users_to_profile_age.keys.to_set
          new_unique_user_proofed_events = this_month_user_proofed_events -
                                           prev_seen_user_proofed_events

          unique_profile_age_counts = this_month_user_proofed_events.group_by do |user_unique_id|
            age = users_to_profile_age[user_unique_id]
            if age.nil? || age < 0
              :unknown
            elsif age > 4
              :older
            else
              age.to_i
            end
          end.tap { |counts| counts.default = [] }

          new_unique_profile_age_counts = new_unique_user_proofed_events.group_by do
                                          |user_unique_id|
            age = users_to_profile_age[user_unique_id]
            if age.nil? || age < 0
              :unknown
            elsif age > 4
              :older
            else
              age.to_i
            end
          end.tap do |counts|
            counts.default = []
          end

          prev_seen_user_proofed_events |= this_month_user_proofed_events

          rows << {
            partner: partner,
            issuers: issuers_set,
            year_month: year_month,
            iaa_start_date: date_range.begin.to_s,
            iaa_end_date: date_range.end.to_s,
            unique_user_proofed_events: this_month_user_proofed_events.count,
            partner_ial2_unique_users_year1: unique_profile_age_counts[0].count,
            partner_ial2_unique_users_year2: unique_profile_age_counts[1].count,
            partner_ial2_unique_users_year3: unique_profile_age_counts[2].count,
            partner_ial2_unique_users_year4: unique_profile_age_counts[3].count,
            partner_ial2_unique_users_year5: unique_profile_age_counts[4].count,
            partner_ial2_unique_users_year_greater_than_5: unique_profile_age_counts[:older].count,
            partner_ial2_unique_users_unknown: unique_profile_age_counts[:unknown].count,
            new_unique_user_proofed_events: new_unique_user_proofed_events.count,
            partner_ial2_new_unique_users_year1: new_unique_profile_age_counts[0].count,
            partner_ial2_new_unique_users_year2: new_unique_profile_age_counts[1].count,
            partner_ial2_new_unique_users_year3: new_unique_profile_age_counts[2].count,
            partner_ial2_new_unique_users_year4: new_unique_profile_age_counts[3].count,
            partner_ial2_new_unique_users_year5: new_unique_profile_age_counts[4].count,
            partner_ial2_new_unique_users_year_greater_than_5: new_unique_profile_age_counts[:older].count, # rubocop:disable Layout/LineLength
            partner_ial2_new_unique_users_unknown: new_unique_profile_age_counts[:unknown].count,
          }
        end
        # rubocop:enable Metrics/BlockLength
        rows
      end

      # @param [Array<String>] issuers all the issuers for this iaa
      # @param [Array<Range<Date>>] months ranges of dates by month that are included in this iaa,
      #  the first and last may be partial months
      # @return [Array<String>]
      def build_queries(issuers:, months:)
        months.map do |month_range| # rubocop:disable Metrics/BlockLength
          params = {
            range_start: month_range.begin,
            range_end: month_range.end,
            year_month: month_range.begin.strftime('%Y%m'),
            issuers: issuers,
          }.transform_values { |value| quote(value) }

          format(<<~SQL, params)
            SELECT
              subq.user_id AS user_id
            , %{year_month} AS year_month
            , subq.profile_verified_at
            , subq.profile_age
            FROM (
              SELECT
                  sp_return_logs.user_id
                , sp_return_logs.profile_verified_at
                , DATE_PART('year', AGE(sp_return_logs.returned_at, sp_return_logs.profile_verified_at)) AS profile_age
              FROM sp_return_logs
              WHERE
                    sp_return_logs.ial > 1
                AND sp_return_logs.returned_at::date BETWEEN %{range_start} AND %{range_end}
                AND sp_return_logs.issuer IN %{issuers}
                AND sp_return_logs.billable = true
            ) subq
            GROUP BY
              subq.user_id
              , subq.profile_verified_at
              , subq.profile_age
          SQL
        end
      end
    end
  end
end
