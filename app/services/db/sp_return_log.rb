module Db
  class SpReturnLog
    def self.create_return(request_id:, user_id:, billable:, ial:, issuer:)
      now = Time.zone.now
      ::SpReturnLog.create!(
        request_id: request_id,
        user_id: user_id,
        billable: billable,
        ial: ial,
        issuer: issuer,
        returned_at: now,
        requested_at: now,
      )
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end
