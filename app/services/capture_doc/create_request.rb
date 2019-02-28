module CaptureDoc
  class CreateRequest
    def self.call(user_id)
      DocCapture.create_with(
        request_token: SecureRandom.uuid,
        requested_at: Time.zone.now,
      ).find_or_create_by(user_id: user_id)
    end
  end
end
