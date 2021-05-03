module Db
  module SpReturnLog
    class AddReturn
      def self.call(request_id, user_id)
        ::SpReturnLog.where(request_id: request_id).update_all(user_id: user_id, returned_at: Time.zone.now)
      end
    end
  end
end
