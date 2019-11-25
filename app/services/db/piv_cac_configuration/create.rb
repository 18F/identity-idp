module Db
  module PivCacConfiguration
    class Create
      def self.call(user_id, x509_dn_uuid, name = '')
        user = User.find_by(id: user_id)
        return unless user
        user.x509_dn_uuid = x509_dn_uuid
        user.save
        ::PivCacConfiguration.create!(user_id: user_id, x509_dn_uuid: x509_dn_uuid, name: name)
      end
    end
  end
end
