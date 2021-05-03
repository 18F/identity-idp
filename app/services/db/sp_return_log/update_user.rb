module Db
  module SpReturnLog
    class UpdateUser
      def self.call(request_id, user_id)
        ::SpReturnLog.where(request_id: request_id).update_all(user_id: user_id)
      end
    end
  end
end
