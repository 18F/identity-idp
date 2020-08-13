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
#   WHERE issuer IN (issuer1, issuer2, ...) AND ial=2
#   AND year_month BETWEEN iaa_start_year_month AND last_month_year_month

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
        sql = format(<<~SQL, sql_params(today))
          SELECT COUNT(*) as active_count FROM identities
          WHERE service_provider in #{issuers}
          AND last_ial#{ial}_authenticated_at >= %{beginning_of_month} and
          user_id IN (select user_id from profiles)
          #{prior_months_sql(ial, today, issuers)}
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

      def prior_months_sql(ial, today, issuers)
        last_month = today.last_month
        return '' if last_month < iaa_start_date
        <<~SQL
          AND user_id NOT IN (
            SELECT DISTINCT user_id
            FROM monthly_sp_auth_counts WHERE issuer IN #{issuers} and ial=#{ial}
            AND year_month BETWEEN '#{year_month(iaa_start_date)}' AND '#{year_month(last_month)}'
          )
        SQL
      end

      def year_month(date)
        date.strftime('%Y%m')
      end
    end
  end
end
