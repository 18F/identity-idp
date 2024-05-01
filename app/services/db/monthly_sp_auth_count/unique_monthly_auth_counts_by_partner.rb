# frozen_string_literal: true

module Db
  module MonthlySpAuthCount
    module UniqueMonthlyAuthCountsByPartner
      extend Reports::QueryHelpers

      module_function

      # @param [String] partner key label for billing
      # @param [Array<String>] issuers issuers for the partner
      # @param [Date] start_date partner start date
      # @param [Date] end_date partner end date
      # @return [PG::Result, Array]
      def call(key:, issuers:, start_date:, end_date:)
        date_range = start_date...end_date

        return [] if !date_range || issuers.blank?

        months = Reports::MonthHelper.months(date_range)
        queries = build_queries(issuers: issuers, months: months)
        puts("queries: #{queries}")
        # ial_to_year_month_to_users = Hash.new do |ial_h, ial_k|
        #   ial_h[ial_k] = Hash.new { |ym_h, ym_k| ym_h[ym_k] = Multiset.new }
        # end
        ial_to_year_month_to_users = Hash.new do |ial_h, ial_k|
          ial_h[ial_k] = Hash.new do |year_h, year_k|
            year_h[year_k] = Hash.new { |month_h, month_k| month_h[month_k] = Multiset.new }
          end
        end
        puts("ial_to_year_month_to_users: #{ial_to_year_month_to_users.inspect}")
        queries.each do |query|
          temp_copy = ial_to_year_month_to_users.deep_dup
          puts("temp_copy: #{temp_copy.inspect}")  
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
                verified_year = row['verified_year']
                verified_month = row['verified_month']
                # year_month = row['year_month']
                auth_count = row['auth_count']
                ial = row['ial']

                ial_to_year_month_to_users[ial][verified_year][verified_month].add(user_id, auth_count)
              end
            end
          end
        end
        puts("ial_to_year_month_to_users end: #{ial_to_year_month_to_users}") 
        rows = []
        puts("year_month_to_users after: #{ial_to_year_month_to_users}")
        ial_to_year_month_to_users.each do |ial, verified_years, verified_months|
          prev_seen_users = Set.new
          puts("prev_seen_users: #{prev_seen_users}")
          # year_months = year_month_to_users.keys.sort
          # puts("year_months: #{year_months}")
          # year_months.each do |year_month|
          #   year_month_users = year_month_to_users[year_month]

          #   auth_count = year_month_users.count
          #   unique_users = year_month_users.uniq.to_set

          #   new_unique_users = unique_users - prev_seen_users
          #   prev_seen_users |= unique_users

          #   rows << {
          #     key: key,
          #     ial: ial,
          #     year: verified_year,
          #     month: verified_month,
          #     year_month: year_month,
          #     iaa_start_date: date_range.begin.to_s,
          #     iaa_end_date: date_range.end.to_s,
          #     total_auth_count: auth_count,
          #     unique_users: unique_users.count,
          #     new_unique_users: new_unique_users.count,
          #   }
          # end
          years = verified_years.keys.sort
          puts("years: #{years}")
          years.each do |year|
            # month_to_users = verified_years[year]
            months = verified_months.keys.sort
            puts("months: #{months}")
            puts("month_to_users: #{month_to_users}")
            months.each do |month|
              month_users = month_to_users[month]

              auth_count = month_users.count
              unique_users = month_users.uniq.to_set

              new_unique_users = unique_users - prev_seen_users
              prev_seen_users |= unique_users

              rows << {
                key: key,
                ial: ial,
                year: year,
                month: month,
                # year_month: "#{year}-#{month}",
                iaa_start_date: date_range.begin.to_s,
                iaa_end_date: date_range.end.to_s,
                total_auth_count: auth_count,
                unique_users: unique_users.count,
                new_unique_users: new_unique_users.count,
              }
            end
          end
        end
        puts("rows: #{rows}")
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
            verified_year: month_range.begin.year,
            verified_month: month_range.begin.month,
            # year_month: month_range.begin.strftime('%Y%m'),
            issuers: issuers,
          }.transform_values { |value| quote(value) }

          format(<<~SQL, params)
            SELECT
              sp_return_logs.user_id
            , %{verified_year} AS verified_year
            , %{verified_month} AS verified_month
            , COUNT(sp_return_logs.id) AS auth_count
            , sp_return_logs.ial
            FROM sp_return_logs
            WHERE
                  sp_return_logs.profile_verified_at::date BETWEEN %{range_start} AND %{range_end}
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
