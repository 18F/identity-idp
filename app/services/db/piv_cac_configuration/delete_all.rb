module Db
  module PivCacConfiguration
    class DeleteAll
      def self.call(user_id)
        ::PivCacConfiguration.where(user_id: user_id).delete_all
      end
    end
  end
end
