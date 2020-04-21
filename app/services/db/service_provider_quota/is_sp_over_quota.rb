module Db
  module ServiceProviderQuota
    class IsSpOverQuota
      def self.call(issuer)
        ::ServiceProviderQuota.find_by(issuer)&.percentage_full.to_i > 100
      end
    end
  end
end
