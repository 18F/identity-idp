module Db
  module PivCacConfiguration
    class Delete
      def self.call(user_id)
        user = User.find(user_id)
        return unless user
        user.x509_dn_uuid = nil
        user.save
        PivCacConfiguration.where(user_id: user_id).delete_all
      end
    end
  end
end
