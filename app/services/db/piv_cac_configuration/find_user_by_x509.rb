module Db
  module PivCacConfiguration
    class FindUserByX509
      def self.call(x509_dn_uuid)
        piv_cac_config = ::PivCacConfiguration.find_by(x509_dn_uuid: x509_dn_uuid)
        piv_cac_config&.user
      end
    end
  end
end
