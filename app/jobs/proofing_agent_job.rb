# frozen_string_literal: true

class ProofingAgentJob < ApplicationJob
  include JobHelpers::StaleJobHelper
  include AbTestingConcern

  queue_as :high_proofing_agent

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  attr_reader :document_capture_session

  def perform(
    encrypted_arguments:,
    trace_id:,
    transaction_id:,
    proofing_agent_id: nil,
    proofing_location_id: nil,
    correlation_id: nil
  )
    timer = JobHelpers::Timer.new

    @document_capture_session = DocumentCaptureSession.find_by(uuid: transaction_id)
    raise ArgumentError, 'DocumentCaptureSession not found' if @document_capture_session.nil?

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    current_sp = ServiceProvider.find_by(issuer: service_provider_issuer)

    applicant_pii = decrypted_args[:applicant_pii]
    applicant_pii[:uuid_prefix] = current_sp&.app_id
    applicant_pii[:uuid] = user.uuid

    proofing_result = make_vendor_proofing_requests(
      timer:,
      applicant_pii:,
      current_sp:,
      trace_id:,
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
    )

    combined_result = proofing_result.combined_result.to_h

    document_capture_session.store_agent_proofed_user(proofing_result.combined_result)

    success = combined_result[:success]
    reason = combined_result[:reason]

    ProofingAgentWebhookJob.perform_later(
      success:,
      reason:,
      transaction_id:,
      correlation_id:,
    )
  ensure
    logger_info_hash(
      name: 'ProofingAgent',
      trace_id:,
      success: combined_result&.dig(:success),
      timing: timer.results,
      user_id: user&.uuid,
    )
  end

  private

  # @return [ProofingAgent::ProofingResult]
  def make_vendor_proofing_requests(
    timer:,
    applicant_pii:,
    current_sp:,
    trace_id:,
    proofing_agent_id:,
    proofing_location_id:,
    correlation_id:
  )
    aamva_result = nil

    if applicant_pii[:state_id_number].present?
      aamva_result = call_aamva_verification(
        applicant_pii:,
        current_sp:,
        timer:,
      )
      applicant_pii[:aamva_verified_attributes] = aamva_result.verified_attributes if aamva_result
    end

    mrz_result = nil

    if applicant_pii[:mrz].present?
      mrz_result = call_mrz_verification(
        applicant_pii:,
        timer:,
      )
    end

    re_encrypted_arguments = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
      { applicant_pii: }.to_json,
    )

    resolution_result = call_resolution_proofing_job(
      timer:,
      result_id: SecureRandom.uuid,
      encrypted_arguments: re_encrypted_arguments,
      trace_id:,
      user_id: user.id,
      service_provider_issuer:,
      proofing_vendor:,
    )

    ProofingAgent::ProofingResult.new(
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      pii: applicant_pii,
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
    proofing_vendor:
  )
    timer.time('resolution') do
      ResolutionProofingJob.perform_now(
        result_id:,
        encrypted_arguments:,
        trace_id:,
        user_id:,
        service_provider_issuer:,
        ipp_enrollment_in_progress: user.has_in_person_enrollment?,
        proofing_vendor:,
      )
    end

    DocumentCaptureSession.new(result_id:).load_proofing_result&.result
  end

  def call_aamva_verification(applicant_pii:, current_sp:, timer:)
    aamva_plugin.call(
      applicant_pii:,
      current_sp:,
      state_id_address_resolution_result: nil,
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

  def proofing_vendor
    @proofing_vendor ||= begin
      # if proofing vendor A/B test is disabled, return default vendor
      vendor = ab_test_bucket(
        :PROOFING_VENDOR,
        user:,
        service_provider: service_provider_issuer,
        current_session: nil,
        current_user_session: nil,
      )

      vendor || IdentityConfig.store.idv_resolution_default_vendor
    end
  end

  def aamva_plugin
    @aamva_plugin ||= Proofing::Resolution::Plugins::AamvaPlugin.new
  end

  def analytics
    @analytics ||= Analytics.new(
      user:,
      request: nil,
      session: {},
      sp: service_provider_issuer,
    )
  end

  def logger_info_hash(hash)
    logger.info(hash.to_json)
  end

  def user
    @user ||= document_capture_session.user
  end

  def service_provider_issuer
    document_capture_session.issuer
  end

  def result_id
    document_capture_session.result_id
  end
end
