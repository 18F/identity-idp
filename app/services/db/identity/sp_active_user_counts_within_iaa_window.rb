module Db
  module Identity
    # Similar to SpActiveUserCounts, but it limits dates to within active IAA windows
    class SpActiveUserCountsWithinIaaWindow
      def self.call
        service_providers = ServiceProvider.arel_table
        identities = ServiceProviderIdentity.arel_table

        ial1_within_iaa = between(
          identities[:last_ial1_authenticated_at],
          service_providers[:iaa_start_date],
          service_providers[:iaa_end_date],
        )

        ial2_within_iaa = between(
          identities[:last_ial2_authenticated_at],
          service_providers[:iaa_start_date],
          service_providers[:iaa_end_date],
        )

        sql = ServiceProvider.
          select(
            service_providers[:issuer],
            service_providers[:app_id].maximum.as('app_id'),
            service_providers[:iaa].maximum.as('iaa'),
            service_providers[:iaa_start_date].minimum.as('iaa_start_date'),
            service_providers[:iaa_end_date].maximum.as('iaa_end_date'),
            sum_if(ial1_within_iaa).as('total_ial1_active'),
            sum_if(ial2_within_iaa).as('total_ial2_active'),
          ).joins(:identities).
          where(
            ial1_within_iaa.or(ial2_within_iaa),
          ).group(service_providers[:issuer]).
          order(service_providers[:issuer]).
          to_sql

        ActiveRecord::Base.connection.execute(sql)
      end

      # Builds "value BETWEEN range_start AND range_end"
      # We need to do this because Arel's value#between() only works on values
      # that can go in the stdlib Range class
      def self.between(value, range_start, range_end)
        Arel::Nodes::Between.new(
          value,
          Arel::Nodes::And.new([range_start, range_end]),
        )
      end

      # Builds psql equivalent of mysql's SUM(IF(condition, 1, 0))
      def self.sum_if(condition)
        Arel::Nodes::Sum.new(
          [
            Arel::Nodes::Case.new.when(condition).then(1).else(0),
          ],
        )
      end
    end
  end
end
