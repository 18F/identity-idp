module Funnel
  module Registration
    class TotalSubmittedCount
      def self.call
        Reports::CountHelper.count_in_batches(RegistrationLog)
      end
    end
  end
end
