module Funnel
  module Registration
    class RangeRegisteredCount
      def self.call(start, finish)
        RegistrationLog.where('? < registered_at AND registered_at < ?', start, finish).count
      end
    end
  end
end
