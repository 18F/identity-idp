module Recover
  class CreateRecoverRequest
    def self.call(user_id)
      recovery_request = AccountRecoveryRequest.find_by(user_id: user_id)
      token = SecureRandom.uuid
      now = Time.zone.now
      if recovery_request
        recovery_request.update!(request_token: token, requested_at: now)
        recovery_request
      else
        AccountRecoveryRequest.create(user_id: user_id, request_token: token, requested_at: now)
      end
    end
  end
end
