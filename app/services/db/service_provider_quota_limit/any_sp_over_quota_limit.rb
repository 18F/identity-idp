module Db
  module ServiceProviderQuotaLimit
    class AnySpOverQuotaLimit
      def self.call
        ::ServiceProviderQuotaLimit.where('percent_full >= 100').any?
      end
    end
  end
end
