# generate incremental IAL2 active user counts by IAA (rolling up applications)
# incremental means a user can only be active for one month in the entire span of the IAA
#
# strategy: get active users in the current month in identities and
# subtract out those active in prior months from monthly_sp_auth_counts
#
# for each IAA:
# SELECT COUNT(*) as active_count FROM identities
# WHERE service_provider in (issuer1, issuer2, ...)
# AND last_ial2_authenticated_at >= first_of_the_month
# AND user_id IN (select user_id from profiles)
# AND user_id NOT IN (
#   SELECT DISTINCT user_id
#   FROM monthly_sp_auth_counts
#   WHERE issuer IN (issuer1, issuer2, ...) and ial=2
#   and year_month in (iaa_start_year_month, iaa_start_year_month+1, ... previous_month)

module Db
  module Identity
    class IaaActiveUserCount
      def initialize(iaa, iaa_start_date, iaa_end_date)
        @iaa = iaa
        @iaa_start_date = iaa_start_date
        @iaa_end_date = iaa_end_date
      end

      def call(ial, today)
        issuers = issuers_sql(iaa)
        return unless issuers
        prior_months = prior_months_sql(today)
        prior_months = from_monthly_sp_counts(issuers, ial, prior_months) if prior_months.present?
        sql = format(<<~SQL, sql_params(today))
          SELECT COUNT(*) as active_count FROM identities
          WHERE service_provider in #{issuers}
          AND last_ial#{ial}_authenticated_at >= %{beginning_of_month} and
          user_id IN (select user_id from profiles)
          #{prior_months}
        SQL
        ActiveRecord::Base.connection.execute(sql)[0]['active_count']
      end

      private

      attr_reader :iaa, :iaa_start_date, :iaa_end_date

      def from_monthly_sp_counts(issuers, ial, prior_months)
        <<~SQL
          AND user_id NOT IN (
            SELECT DISTINCT user_id FROM monthly_sp_auth_counts WHERE issuer IN #{issuers} and ial=#{ial}
            #{prior_months}
          )
        SQL
      end

      def sql_params(today)
        {
          beginning_of_month: ActiveRecord::Base.connection.quote(today.beginning_of_month),
        }
      end

      def issuers_sql(iaa)
        sps = ServiceProvider.where(iaa: iaa)
        return if sps.blank?
        "(#{sps.map { |sp| "'#{sp.issuer}'" }.join(',')})"
      end

      def prior_months_sql(today)
        last_month = today.month - 1
        last_month = 12 if last_month < 1
        iaa_start_month = iaa_start_date.month
        return '' if last_month == iaa_start_month
        months_sql(last_month, iaa_start_month, today)
      end

      def months_sql(last_month, iaa_start_month, today)
        if iaa_start_month < last_month
          list_to_sql(year_month_list(iaa_start_month, last_month, today.year))
        else
          list = year_month_list(iaa_start_month, 12, today.year - 1) +
                 year_month_list(1,
                                 last_month < iaa_end_date.month ? last_month : iaa_end_date.month,
                                 today.year)
          list_to_sql(list)
        end
      end

      def list_to_sql(list)
        list = list.map { |val| "'#{val}'" }
        "and year_month in (#{list.join(',')})"
      end

      def year_month_list(start_month, finish_month, year)
        (start_month..finish_month).to_a.map { |val| format('%04d%02d', year, val) }
      end
    end
  end
end
