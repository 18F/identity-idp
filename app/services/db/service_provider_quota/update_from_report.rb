module Db
  module ServiceProviderQuota
    class UpdateFromReport
      def self.call(report_data)
        report_data.each do |rec|
          ::ServiceProviderQuota.find_or_create_by(issuer: rec['issuer'], ial: rec['ial'])&.
            update!(percent_full: rec['percent_ial2_quota'])
        end
      end
    end
  end
end
