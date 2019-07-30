module Funnel
  module Registration
    class TotalRegisteredCount
      def self.call
        RegistrationLog.where.not(registered_at: nil).count
      end
    end
  end
end
