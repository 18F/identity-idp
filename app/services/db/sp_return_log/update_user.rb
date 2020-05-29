module Db
  module SpReturnLog
    class UpdateUser
      def self.call(request_id, user_id)
        sp_return_log = ::SpReturnLog.find_by(request_id: request_id)
        return unless sp_return_log
        sp_return_log.user_id = user_id
        sp_return_log.save
      end
    end
  end
end
