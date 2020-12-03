module Funnel
  module Registration
    class RangeRegisteredCount
      def self.call(start, finish)
        Reports::CountHelper.count_in_batches(RegistrationLog.where(registered_at: (start..finish)))
      end
    end
  end
end
