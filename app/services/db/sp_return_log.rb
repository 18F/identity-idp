module Db
  class SpReturnLog
    # rubocop:disable Rails/SkipsModelValidations
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
      # Can be removed after deploy of RC 185
      ::SpReturnLog.where(request_id: request_id).update_all(
        user_id: user_id,
        returned_at: Time.zone.now,
        billable: billable,
        ial: ial,
      )
      nil
    end
    # rubocop:enable Rails/SkipsModelValidations
  end
end
