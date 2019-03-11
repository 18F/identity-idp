module CaptureDoc
  class UpdateAcuantToken
    def self.call(user_id, acuant_token)
      doc_capture = DocCapture.find_by(user_id: user_id)
      return unless doc_capture
      doc_capture.update!(acuant_token: acuant_token)
    end
  end
end
