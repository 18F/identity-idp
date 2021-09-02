module Db
  module ServiceProviderQuotaLimit
    class UpdateFromReport
      def self.call(report_data)
        report_data.each do |rec|
          ::ServiceProviderQuotaLimit.
            create_or_find_by(issuer: rec['issuer'], ial: 2)&.
            update!(percent_full: rec['percent_ial2_quota'])
        end
      end
    end
  end
end
