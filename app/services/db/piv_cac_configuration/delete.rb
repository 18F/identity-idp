module Db
  module PivCacConfiguration
    class Delete
      def self.call(user_id, cfg_id)
        ::PivCacConfiguration.where(user_id: user_id, id: cfg_id).delete_all
      end
    end
  end
end
