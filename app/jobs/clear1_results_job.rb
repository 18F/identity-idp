# frozen_string_literal: true

class Clear1ResultsJob < ApplicationJob
  queue_as :high_clear1

  attr_reader :document_capture_session_uuid, :async, :token, :state

  # @param [String] document_capture_session_uuid
  def perform(document_capture_session_uuid:, token:, state:, async: true)
    @document_capture_session_uuid = document_capture_session_uuid
    @async = async
    @token = token
    @state = state

    raise "DocumentCaptureSession not found: #{document_capture_session_uuid}" unless
      document_capture_session

    timer = JobHelpers::Timer.new
    clear1_result_response = timer.time('vendor_request') do
      Proofing::Clear::Requests::Clear1ResultRequest.new(
        customer_user_id: user_uuid,
        document_capture_session_uuid:,
        docv_transaction_token_override:,
        user_email: document_capture_session&.user&.last_sign_in_email_address&.email,
      ).fetch
    end

    document_capture_session.store_proofing_result(clear1_result_response)
  rescue => err
    NewRelic::Agent.notice_error(err)
  end

  private

  def analytics
    @analytics ||= Analytics.new(
      user: document_capture_session.user,
      request: nil,
      session: {},
      sp: document_capture_session.issuer,
    )
  end

  def document_capture_session
    @document_capture_session ||=
      DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
  end
end
