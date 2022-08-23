class DocumentCaptureResultChannel < ApplicationCable::Channel
  def subscribed
    stream_for document_capture_session
    transmit({}) if already_has_result?
  end

  private

  def document_capture_session
    DocumentCaptureSession.find_by(uuid: params[:document_capture_session_uuid])
  end

  def already_has_result?
    document_capture_session.load_proofing_result.present?
  end
end
