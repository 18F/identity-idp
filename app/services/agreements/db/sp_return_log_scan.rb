module Agreements
  module Db
    class SpReturnLogScan
      def self.call
        SpReturnLog.
          select(:id, :issuer, :ial, :user_id, :requested_at, :returned_at).
          find_in_batches(batch_size: 10_000) do |batch|
            batch.each do |return_log|
              yield return_log
            end
          end
      end
    end
  end
end
