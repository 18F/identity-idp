module Db
  class SpReturnLog
    def self.create_return(request_id:, user_id:, billable:, ial:, issuer:, requested_at:)
      ::SpReturnLog.create!(
        request_id: request_id,
        user_id: user_id,
        billable: billable,
        ial: ial,
        issuer: issuer,
        requested_at: requested_at,
        returned_at: Time.zone.now,
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end
