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
                ial = row['ial']
                if row['min_returned_at'].nil? 
                  next
                elsif row['max_profile_verified_at'].nil?
                  profile_age = -1
                else
                  profile_age = (Time.zone.parse(row['min_returned_at'].to_s).year - Time.zone.parse(row['max_profile_verified_at'].to_s).year)
                end
                ial_to_year_month_to_users[ial][year_month].add([user_id, profile_age])
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
            new_unique_users_year1 = new_unique_users.select { |user_id, profile_age| profile_age == 0 }
            new_unique_users_year2 = new_unique_users.select { |user_id, profile_age| profile_age == 1 }
            new_unique_users_year3 = new_unique_users.select { |user_id, profile_age| profile_age == 2 }
            new_unique_users_year4 = new_unique_users.select { |user_id, profile_age| profile_age == 3 }
            new_unique_users_year5 = new_unique_users.select { |user_id, profile_age| profile_age == 4 }
            new_unique_users_year_greater_than_5 = new_unique_users.select { |user_id, profile_age| profile_age > 4 }
            new_unique_users_unknown = new_unique_users.select { |user_id, profile_age| profile_age < 0 }
            prev_seen_users |= unique_users

            rows << {
              key: key,
              ial: ial,
              year_month: year_month,
              iaa_start_date: date_range.begin.to_s,
              iaa_end_date: date_range.end.to_s,
              unique_users: unique_users.count,
              new_unique_users: new_unique_users.count,
              partner_ial2_new_unique_users_year1: new_unique_users_year1.count,
              partner_ial2_new_unique_users_year2: new_unique_users_year2.count,
              partner_ial2_new_unique_users_year3: new_unique_users_year3.count,
              partner_ial2_new_unique_users_year4: new_unique_users_year4.count,
              partner_ial2_new_unique_users_year5: new_unique_users_year5.count,
              partner_ial2_new_unique_users_year_greater_than_5: new_unique_users_year_greater_than_5.count,
              partner_ial2_new_unique_users_unknown: new_unique_users_unknown.count,
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
          params = {
            range_start: month_range.begin,
            range_end: month_range.end,
            year_month: month_range.begin.strftime('%Y%m'),
            issuers: issuers,
          }.transform_values { |value| quote(value) }



          format(<<~SQL, params)
            SELECT
              sp_return_logs.user_id
            , %{year_month} AS year_month
            , sp_return_logs.ial
            , MIN(sp_return_logs.returned_at) AS min_returned_at
            , MAX(sp_return_logs.profile_verified_at) AS max_profile_verified_at

            FROM sp_return_logs
            WHERE
                  sp_return_logs.returned_at::date BETWEEN %{range_start} AND %{range_end}
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
