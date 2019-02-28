module CaptureDoc
  class UpdateAcuantToken
    def self.call(user_id, acuant_token)
      DocCapture.find_by(user_id: user_id).update!(acuant_token: acuant_token)
    end
  end
end
