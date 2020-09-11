module Db
  module PivCacConfiguration
    class Create
      def self.call(user, x509_dn_uuid, name = x509_dn_uuid, issuer = nil)
        user.piv_cac_configurations.create!(x509_dn_uuid: x509_dn_uuid,
                                            name: name,
                                            x509_issuer: issuer)
      end
    end
  end
end
