module Funnel
  module Registration
    class RangeSubmittedCount
      def self.call(start, finish)
        RegistrationFunnel.where('? < submitted_at AND submitted_at > ?', start, finish).count
      end
    end
  end
end
