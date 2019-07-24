module Funnel
  module Registration
    class TotalSubmittedCount
      def self.call
        RegistrationLog.count
      end
    end
  end
end
