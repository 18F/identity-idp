module Idv
  module StepUtilitiesConcern
    extend ActiveSupport::Concern
    include AcuantConcern

    def irs_reproofing?
      current_user&.reproof_for_irs?(
        service_provider: current_sp,
      ).present?
    end

    def document_capture_session_uuid
      flow_session[:document_capture_session_uuid]
    end

    def document_capture_session
      return @document_capture_session if defined?(@document_capture_session)
      @document_capture_session = DocumentCaptureSession.find_by(
        uuid: document_capture_session_uuid,
      )
    end
  end
end
