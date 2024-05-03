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

        ial_to_year_month_to_users = Hash.new do |ial_h, ial_k|
          ial_h[ial_k] = Hash.new { |ym_h, ym_k| ym_h[ym_k] = Multiset.new }
        end

        queries.each do |query|
          temp_copy = ial_to_year_month_to_users.deep_dup

          with_retries(
            max_tries: 3,
            rescue: [
              ActiveRecord::SerializationFailure,
              PG::ConnectionBad,
              PG::TRSerializationFailure,
              PG::UnableToSend,
            ],
            handler: proc do
              ial_to_year_month_to_users = temp_copy
              ActiveRecord::Base.connection.reconnect!
            end,
          ) do
            Reports::BaseReport.transaction_with_timeout do
              ActiveRecord::Base.connection.execute(query).each do |row|
                user_id = row['user_id']
                year_month = row['year_month']
                auth_count = row['auth_count']
                ial = row['ial']

                ial_to_year_month_to_users[ial][year_month].add(user_id, auth_count)
              end
            end
          end
        end

        rows = []

        ial_to_year_month_to_users.each do |ial, year_month_to_users|
          prev_seen_users = Set.new

          year_months = year_month_to_users.keys.sort

          year_months.each do |year_month|
            year_month_users = year_month_to_users[year_month]

            auth_count = year_month_users.count
            unique_users = year_month_users.uniq.to_set

            new_unique_users = unique_users - prev_seen_users
            prev_seen_users |= unique_users

            rows << {
              key: key,
              ial: ial,
              year_month: year_month,
              iaa_start_date: date_range.begin.to_s,
              iaa_end_date: date_range.end.to_s,
              total_auth_count: auth_count,
              unique_users: unique_users.count,
              new_unique_users: new_unique_users.count,
            }
          end
        end

        rows
      end

      # @param [Array<String>] issuers all the issuers for this iaa
      # @param [Array<Range<Date>>] months ranges of dates by month that are included in this iaa,
      #  the first and last may be partial months
      # @return [Array<String>]
      def build_queries(issuers:, months:)
        months.map do |month_range|
          today = Date.today
          params = {
            range_start: month_range.begin,
            range_end: month_range.end,
            year_month: month_range.begin.strftime('%Y%m'),
            issuers: issuers,
            one_years_ago: today - 365,
            two_years_ago: today - 2 * 365,
            three_years_ago: today - 3 * 365,
            four_years_ago: today - 4 * 365,
            five_years_ago: today - 5 * 365,
          }.transform_values { |value| quote(value) }



          format(<<~SQL, params)
            SELECT
              sp_return_logs.user_id
            , %{year_month} AS year_month
            , COUNT(sp_return_logs.id) AS auth_count
            , sp_return_logs.ial
            , SUM (
              CASE WHEN sp_return_logs.profile_verified_at IS BETWEEN %{now) AND %{one_years_ago}
              THEN 1 ELSE 0 END) as partner_ial2_new_unique_users_year1
            , SUM (
              CASE WHEN sp_return_logs.profile_verified_at IS BETWEEN %{one_years_ago) AND %{two_years_ago}
              THEN 1 ELSE 0 END) as partner_ial2_new_unique_users_year2
            , SUM (
              CASE WHEN sp_return_logs.profile_verified_at IS BETWEEN %{two_years_ago) AND %{three_years_ago}
              THEN 1 ELSE 0 END) as partner_ial2_new_unique_users_year3
            , SUM (
              CASE WHEN sp_return_logs.profile_verified_at IS BETWEEN %{three_years_ago) AND %{four_years_ago}
              THEN 1 ELSE 0 END) as partner_ial2_new_unique_users_year4
            , SUM (
              CASE WHEN sp_return_logs.profile_verified_at IS BETWEEN %{four_years_ago) AND %{five_years_ago}
              THEN 1 ELSE 0 END) as partner_ial2_new_unique_users_year5
            , SUM (
              CASE WHEN sp_return_logs.profile_verified_at > %{five_years_ago} 
              THEN 1 ELSE 0 END) as partner_ial2_new_unique_users_year_greater_than_5
            , SUM (
              CASE When sp_return_logs.ial = 2 AND sp_return_logs.profile_verified_at IS NULL
              THEN 1 ELSE 0 END) as partner_ial2_new_unique_users_unknown

            FROM sp_return_logs
            WHERE
              AND sp_return_logs.issuer IN %{issuers}
              AND sp_return_logs.billable = true
            GROUP BY
              sp_return_logs.user_id
            , sp_return_logs.ial
          SQL
        end
      end
    end
  end
end
