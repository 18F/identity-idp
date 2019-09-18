module Db
  module SpReturnLog
    class CreateRequest
      def self.call(request_id, ial, issuer)
        ::SpReturnLog.create!(
          request_id: request_id,
          ial: ial,
          issuer: issuer,
          requested_at: Time.zone.now,
        )
      rescue ActiveRecord::RecordNotUnique
        nil
      end
    end
  end
end
