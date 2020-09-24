module CaptureDoc
  class CreateRequest
    def self.call(user_id, sp_session)
      doc_capture = DocCapture.find_by(user_id: user_id)

      if doc_capture
        doc_capture.update!(acuant_token: nil, **doc_capture_attributes(sp_session))
        doc_capture
      else
        DocCapture.create(user_id: user_id, **doc_capture_attributes(sp_session))
      end
    end

    def self.doc_capture_attributes(sp_session)
      {
        request_token: SecureRandom.uuid,
        requested_at: Time.zone.now,
        issuer: sp_session[:issuer],
        ial2_strict: sp_session[:ial2_strict],
      }
    end
  end
end
