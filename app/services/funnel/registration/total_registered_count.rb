module Funnel
  module Registration
    class TotalRegisteredCount
      def self.call
        Reports::CountHelper.count_in_batches(RegistrationLog.where.not(registered_at: nil))
      end
    end
  end
end
