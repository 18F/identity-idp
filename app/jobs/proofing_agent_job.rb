# frozen_string_literal: true

class ProofingAgentJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_proofing_agent

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(
    result_id:,
    encrypted_arguments:,
    trace_id:,
    user_id:,
    webhook_url:,
    transaction_id:,
    proofing_vendor:,
    service_provider_issuer: nil,
    ipp_enrollment_in_progress: false,
    proofing_agent_id: nil,
    proofing_location_id: nil,
    correlation_id: nil
  )
    timer = JobHelpers::Timer.new

    @user = User.find_by(id: user_id)
    raise ArgumentError, 'User not found' if @user.nil?

    @service_provider_issuer = service_provider_issuer

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    current_sp = ServiceProvider.find_by(issuer: service_provider_issuer)

    applicant_pii = decrypted_args[:applicant_pii]
    applicant_pii[:uuid_prefix] = current_sp&.app_id
    applicant_pii[:uuid] = @user.uuid

    proofing_result = make_vendor_proofing_requests(
      timer:,
      applicant_pii:,
      current_sp:,
      result_id:,
      encrypted_arguments:,
      trace_id:,
      user_id:,
      service_provider_issuer:,
      ipp_enrollment_in_progress:,
      proofing_vendor:,
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
    )

    combined_result = proofing_result.combined_result.to_h

    document_capture_session = DocumentCaptureSession.new(result_id:)
    document_capture_session.store_proofing_result(proofing_result.combined_result)

    success = combined_result[:success]
    reason = combined_result[:reason]

    ProofingAgentWebhookJob.perform_later(
      webhook_url:,
      success:,
      reason:,
      transaction_id:,
    )
  ensure
    logger_info_hash(
      name: 'ProofingAgent',
      trace_id:,
      success: combined_result&.dig(:success),
      timing: timer.results,
      user_id: @user&.uuid,
    )
  end

  private

  # @return [ProofingAgent::ProofingResult]
  def make_vendor_proofing_requests(
    timer:,
    applicant_pii:,
    current_sp:,
    result_id:,
    encrypted_arguments:,
    trace_id:,
    user_id:,
    service_provider_issuer:,
    ipp_enrollment_in_progress:,
    proofing_vendor:,
    proofing_agent_id:,
    proofing_location_id:,
    correlation_id:
  )
    resolution_result = call_resolution_proofing_job(
      timer:,
      result_id:,
      encrypted_arguments:,
      trace_id:,
      user_id:,
      service_provider_issuer:,
      ipp_enrollment_in_progress:,
      proofing_vendor:,
    )

    if applicant_pii[:state_id_number].present?
      aamva_result = call_aamva_verification(
        applicant_pii:,
        current_sp:,
        resolution_result:,
        timer:,
      )
    end

    if applicant_pii[:mrz].present?
      mrz_result = call_mrz_verification(
        applicant_pii:,
        timer:,
      )
    end

    ProofingAgent::ProofingResult.new(
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      resolution_result:,
      aamva_result:,
      mrz_result:,
      service_provider_issuer:,
    )
  end

  def call_resolution_proofing_job(
    timer:,
    result_id:,
    encrypted_arguments:,
    trace_id:,
    user_id:,
    service_provider_issuer:,
    ipp_enrollment_in_progress:,
    proofing_vendor:
  )
    timer.time('resolution') do
      ResolutionProofingJob.perform_now(
        result_id:,
        encrypted_arguments:,
        trace_id:,
        user_id:,
        service_provider_issuer:,
        ipp_enrollment_in_progress:,
        proofing_vendor:,
      )
    end

    DocumentCaptureSession.new(result_id:).load_proofing_result&.result
  end

  def call_aamva_verification(applicant_pii:, current_sp:, resolution_result:, timer:)
    state_id_address_resolution_result =
      if resolution_result.present?
        Proofing::Resolution::Result.new(
          success: resolution_result[:success],
          errors: resolution_result[:errors] || {},
          exception: resolution_result[:exception],
        )
      end

    aamva_plugin.call(
      applicant_pii:,
      current_sp:,
      state_id_address_resolution_result:,
      ipp_enrollment_in_progress: false,
      timer:,
      doc_auth_flow: true,
      analytics:,
    )
  end

  def call_mrz_verification(applicant_pii:, timer:)
    mrz = applicant_pii[:mrz]
    return nil if mrz.blank?

    mrz_client = if IdentityConfig.store.proofer_mock_fallback
                   DocAuth::Mock::DosPassportApiClient.new
                 else
                   DocAuth::Dos::Requests::MrzRequest.new(mrz:)
                 end

    timer.time('mrz') { mrz_client.fetch }
  end

  def aamva_plugin
    @aamva_plugin ||= Proofing::Resolution::Plugins::AamvaPlugin.new
  end

  def analytics
    @analytics ||= Analytics.new(
      user: @user,
      request: nil,
      session: {},
      sp: @service_provider_issuer,
    )
  end

  def logger_info_hash(hash)
    logger.info(hash.to_json)
  end
end
