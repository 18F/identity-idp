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
        and_month_in_iaa_start_month_to_last_month = prior_months_sql(today)
        sql = format(<<~SQL, sql_params(today))
          SELECT COUNT(*) FROM identities
          WHERE service_provider in #{issuers}
          AND last_ial#{ial}_authenticated_at >= %{beginning_of_month} and
          user_id NOT IN (
            SELECT DISTINCT user_id FROM monthly_sp_auth_counts
            WHERE issuer IN #{issuers} and ial=#{ial}
            #{and_month_in_iaa_start_month_to_last_month}
          )
        SQL
        ActiveRecord::Base.connection.execute(sql)[0]
      end

      private

      attr_reader :iaa, :iaa_start_date, :iaa_end_date

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
