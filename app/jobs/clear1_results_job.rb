# frozen_string_literal: true

class Clear1ResultsJob < ApplicationJob
  queue_as :high_clear1

  attr_reader :document_capture_session_uuid, :async, :verification_session_id

  # @param [String] document_capture_session_uuid
  def perform(document_capture_session_uuid:, verification_session_id:)
    @verification_session_id = verification_session_id
    @document_capture_session_uuid = document_capture_session_uuid

    raise "DocumentCaptureSession not found: #{document_capture_session_uuid}" unless
      document_capture_session

    timer = JobHelpers::Timer.new
    clear1_result_response = timer.time('vendor_request') do
      Proofing::Clear::Requests::ResultRequest.new(
        document_capture_session:,
        verification_session_id:,
      ).fetch
    end

    store_clear1_result(clear1_result_response)
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

  def store_clear1_result(agent_proofing_result)
    session_result = Idv::ProofingAgent::AgentProofedUser.new(id: generate_result_id)

    session_result.success = agent_proofing_result[:success]
    session_result.reason = agent_proofing_result[:reason]
    session_result.pii = agent_proofing_result[:pii]
    session_result.proofing_location_id = agent_proofing_result[:proofing_location_id]
    session_result.proofing_agent_id = agent_proofing_result[:proofing_agent_id]
    session_result.correlation_id = agent_proofing_result[:correlation_id]
    session_result.transaction_id = agent_proofing_result[:transaction_id]
    session_result.issuer = agent_proofing_result[:service_provider_issuer]
    session_result.resolution = agent_proofing_result[:resolution]
    session_result.mrz_status = determine_mrz_status(agent_proofing_result[:mrz])
    aamva_response = agent_proofing_result[:aamva]
    session_result.aamva_status = determine_aamva_status(aamva_response)
    if aamva_response&.dig(:success)
      session_result.aamva_verified_attributes = aamva_response.dig(:extra, :verified_attributes)
    end
    session_result.source_check_vendor = determine_source_check_vendor(
      aamva: aamva_response,
      mrz: agent_proofing_result[:mrz],
    )
    session_result.verified_at = Time.zone.now.to_s # UTC

    EncryptedRedisStructStorage.store(
      session_result,
      expires_in: IdentityConfig.store.agent_proofed_user_time_validity_hours.hours.in_seconds,
    )
    save!
    update!(pending_agent_proofed_user_at: Time.zone.now) if agent_proofing_result[:success]
  end
end
