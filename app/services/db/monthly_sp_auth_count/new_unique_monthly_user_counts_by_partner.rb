# frozen_string_literal: true

module Db
  module MonthlySpAuthCount
    module NewUniqueMonthlyUserCountsByPartner
      extend Reports::QueryHelpers

      UserVerifiedKey = Data.define(
        :user_id, :profile_id, :profile_age, :issuer, :profile_requested_issuer
      ).freeze

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

        # rubocop:disable Metrics/BlockLength
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
                profile_id = row['profile_id']
                profile_requested_issuer = row['profile_requested_issuer']
                issuer = row['issuer']

                user_unique_id = UserVerifiedKey.new(
                  user_id:,
                  profile_id:,
                  profile_age:,
                  issuer:,
                  profile_requested_issuer:,
                )

                year_month_to_users_to_profile_age[year_month][user_unique_id] = profile_age
              end
            end
          end
        end
        # rubocop:enable Metrics/BlockLength
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

          unique_profiles_by_age = bucket_by_profile_age(this_month_user_proofed_events)
          new_unique_profiles_by_age = bucket_by_profile_age(new_unique_user_proofed_events)
          new_unique_profiles_year1 = bucket_by_upfront_existing(new_unique_user_proofed_events)

          prev_seen_user_proofed_events |= this_month_user_proofed_events

          rows << {
            partner: partner,
            issuers: issuers_set,
            year_month: year_month,
            iaa_start_date: date_range.begin.to_s,
            iaa_end_date: date_range.end.to_s,
            unique_user_proofed_events: this_month_user_proofed_events.count,
            partner_ial2_unique_user_events_year1: unique_profiles_by_age[0].count,
            partner_ial2_unique_user_events_year2: unique_profiles_by_age[1].count,
            partner_ial2_unique_user_events_year3: unique_profiles_by_age[2].count,
            partner_ial2_unique_user_events_year4: unique_profiles_by_age[3].count,
            partner_ial2_unique_user_events_year5: unique_profiles_by_age[4].count,
            partner_ial2_unique_user_events_year_greater_than_5: unique_profiles_by_age[:older].count, # rubocop:disable Layout/LineLength
            partner_ial2_unique_user_events_unknown: unique_profiles_by_age[:unknown].count,
            new_unique_user_proofed_events: new_unique_user_proofed_events.count,
            partner_ial2_new_unique_user_events_year1_upfront: new_unique_profiles_year1[:upfront].count, # rubocop:disable Layout/LineLength
            partner_ial2_new_unique_user_events_year1_existing: new_unique_profiles_year1[:existing].count, # rubocop:disable Layout/LineLength
            partner_ial2_new_unique_user_events_year1: new_unique_profiles_by_age[0].count,
            partner_ial2_new_unique_user_events_year2: new_unique_profiles_by_age[1].count,
            partner_ial2_new_unique_user_events_year3: new_unique_profiles_by_age[2].count,
            partner_ial2_new_unique_user_events_year4: new_unique_profiles_by_age[3].count,
            partner_ial2_new_unique_user_events_year5: new_unique_profiles_by_age[4].count,
            partner_ial2_new_unique_user_events_year_greater_than_5: new_unique_profiles_by_age[:older].count, # rubocop:disable Layout/LineLength
            partner_ial2_new_unique_user_events_unknown: new_unique_profiles_by_age[:unknown].count,
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
              user_id
            , %{year_month} AS year_month
            , profile_id
            , DATE_PART('year', AGE(returned_at, profile_verified_at)) AS profile_age
            , profile_requested_issuer
            , issuer
            FROM sp_return_logs
            WHERE
                  ial > 1
              AND returned_at::date BETWEEN %{range_start} AND %{range_end}
              AND issuer IN %{issuers}
              AND billable = true
            GROUP BY
              user_id
              , profile_id
              , DATE_PART('year', AGE(returned_at, profile_verified_at))
              , profile_requested_issuer
              , issuer
          SQL
        end
      end

      def bucket_by_profile_age(unique_user_events)
        unique_user_events.group_by do |user_unique_id|
          age = user_unique_id.profile_age
          if age.nil? || age < 0
            :unknown
          elsif age > 4
            :older
          else
            age.to_i
          end
        end.tap { |counts| counts.default = [] }
      end

      def bucket_by_upfront_existing(unique_user_events)
        year1_events = unique_user_events.select do |user_unique_id|
          age = user_unique_id.profile_age
          !age.nil? && !age.negative? && age == 0
        end

        initially_upfront, existing = year1_events.partition do |event|
          event.issuer == event.profile_requested_issuer
        end

        profiles_already_upfront = Set.new
        upfront = []

        initially_upfront.each do |event|
          profile_key = [event.user_id, event.profile_id, event.issuer]
          if profiles_already_upfront.add?(profile_key)
            upfront << event
          else
            existing << event
          end
        end

        {
          upfront: upfront,
          existing: existing,
        }.tap { |counts| counts.default = [] }
      end
    end
  end
end
