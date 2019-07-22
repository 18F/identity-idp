module Funnel
  module Registration
    class TotalSubmittedCount
      def call
        RegistrationFunnel.count
      end
    end
  end
end
