# frozen_string_literal: true

module Db
  module MonthlySpAuthCount
    module UniqueMonthlyAuthCountsByPartner
      extend Reports::QueryHelpers

      module_function

      # @param [String] key label for billing (Partner requesting agency)
      # @param [Array<String>] issuers issuers for the iaa
      # @param [Date] start_date iaa start date
      # @param [Date] end_date iaa end date
      # @return [PG::Result, Array]
      def call(key:, issuers:, start_date:, end_date:)
        date_range = start_date...end_date

        return [] if !date_range || issuers.blank?

        # Query a month at a time, to keep query time/result size fairly reasonable
        # The results are rows with [user_id, ial, auth_count, year_month]
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
                user_id = row['user_id']
                year_month = row['year_month']
                profile_age = row['profile_age']

                year_month_to_users_to_profile_age[year_month][user_id] = profile_age
              end
            end
          end
        end

        rows = []

        prev_seen_users = Set.new
        year_months = year_month_to_users_to_profile_age.keys.sort

        # rubocop:disable Metrics/BlockLength
        year_months.each do |year_month|
          users_to_profile_age = year_month_to_users_to_profile_age[year_month]

          this_month_users = users_to_profile_age.keys.to_set
          new_unique_users = this_month_users - prev_seen_users

          profile_age_counts = new_unique_users.group_by do |user_id|
            age = users_to_profile_age[user_id]
            if age.nil? || age < 0
              :unknown
            elsif age > 4
              :older
            else
              age.to_i
            end
          end.tap { |counts| counts.default = [] }

          prev_seen_users |= this_month_users

          rows << {
            key: key,
            year_month: year_month,
            iaa_start_date: date_range.begin.to_s,
            iaa_end_date: date_range.end.to_s,
            unique_users: this_month_users.count,
            new_unique_users: new_unique_users.count,
            partner_ial2_new_unique_users_year1: profile_age_counts[0].count,
            partner_ial2_new_unique_users_year2: profile_age_counts[1].count,
            partner_ial2_new_unique_users_year3: profile_age_counts[2].count,
            partner_ial2_new_unique_users_year4: profile_age_counts[3].count,
            partner_ial2_new_unique_users_year5: profile_age_counts[4].count,
            partner_ial2_new_unique_users_year_greater_than_5: profile_age_counts[:older].count,
            partner_ial2_new_unique_users_unknown: profile_age_counts[:unknown].count,
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
        months.map do |month_range|
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
            , MIN(subq.profile_age) AS profile_age
            FROM (
              SELECT
                  sp_return_logs.user_id
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
          SQL
        end
      end
    end
  end
end
