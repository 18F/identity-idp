module Db
  module ServiceProviderQuotaLimit
    class IsSpOverQuota
      def self.call(issuer)
        ::ServiceProviderQuotaLimit.find_by(issuer: issuer)&.percentage_full.to_i > 100
      end
    end
  end
end
