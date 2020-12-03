module Funnel
  module Registration
    class RangeSubmittedCount
      def self.call(start, finish)
        Reports::CountHelper.count_in_batches(RegistrationLog.where(submitted_at: (start..finish)))
      end
    end
  end
end
