module Db
  module PivCacConfiguration
    class Create
      def self.call(user_id, x509_dn_uuid, name = x509_dn_uuid)
        ::PivCacConfiguration.create!(user_id: user_id, x509_dn_uuid: x509_dn_uuid, name: name)
      end
    end
  end
end
