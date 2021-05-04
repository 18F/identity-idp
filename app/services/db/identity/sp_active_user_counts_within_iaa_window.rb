module Db
  module Identity
    # Similar to SpActiveUserCounts, but it limits dates to within active IAA windows
    class SpActiveUserCountsWithinIaaWindow
      def self.call
        min_date, max_date = ServiceProvider.
          where.not(iaa_start_date: nil).
          where.not(iaa_end_date: nil).
          pluck(:iaa_start_date, :iaa_end_date).
          flatten.minmax

        # issuer => ial => Set<UserIds>
        by_issuer = Hash.new do |h, k|
          h[k] = Hash.new { |h, k| h[k] = Set.new }
        end

        ::SpReturnLog.
          where(returned_at: min_date..max_date).
          includes(:service_provider).
          find_in_batches(batch_size: 100_000) do |sp_return_logs|
            sp_return_logs.each do |sp_return_log|
              service_provider = sp_return_log.service_provider

              next if service_provider.nil? # guard against bad legacy data

              iaa_range = service_provider.iaa_start_date..service_provider.iaa_end_date

              if iaa_range.cover?(sp_return_log.returned_at)
                by_issuer[service_provider.issuer][sp_return_log.ial] << sp_return_log.user_id
              end
            end
            puts sp_return_logs.size
            puts by_issuer.size
          end

        by_issuer.map do |issuer, ial_to_user_ids|
          service_provider = ServiceProvider.from_issuer(issuer)

          {
            issuer: service_provider.issuer,
            app_id: service_provider.app_id,
            iaa: service_provider.iaa,
            iaa_start_date: service_provider.iaa_start_date.to_s,
            iaa_end_date: service_provider.iaa_end_date.to_s,
            total_ial1_active: ial_to_user_ids[1].size,
            total_ial2_active: ial_to_user_ids[2].size,
          }
        end
      end
    end
  end
end
