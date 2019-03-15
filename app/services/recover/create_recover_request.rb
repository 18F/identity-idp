module Recover
  class CreateRecoverRequest
    def self.call(user_id)
      doc_capture = AccountRecoveryRequest.find_by(user_id: user_id)
      token = SecureRandom.uuid
      now = Time.zone.now
      if doc_capture
        doc_capture.update!(request_token: token, requested_at: now)
        doc_capture
      else
        AccountRecoveryRequest.create(user_id: user_id, request_token: token, requested_at: now)
      end
    end
  end
end
