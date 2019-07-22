module Funnel
  module Registration
    class TotalSubmittedCount
      def self.call
        RegistrationFunnel.count
      end
    end
  end
end
