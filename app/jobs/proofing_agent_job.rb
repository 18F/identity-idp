# frozen_string_literal: true

class ProofingAgentJob < ApplicationJob
  include JobHelpers::StaleJobHelper
  include AbTestingConcern
  include ProofingAgent::Config

  queue_as :high_proofing_agent

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  attr_reader :document_capture_session

  def perform(
    encrypted_arguments:,
    trace_id:,
    transaction_id:,
    submit_attempts:,
    remaining_attempts:,
    proofing_agent_id: nil,
    proofing_location_id: nil,
    correlation_id: nil,
    final_attempt: false
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
      transaction_id:,
      submit_attempts:,
      remaining_attempts:,
    )

    combined_result = proofing_result.combined_result.to_h

    document_capture_session.store_agent_proofed_user(proofing_result.combined_result)

    success = combined_result[:success]
    reason = combined_result[:reason]

    analytics_attributes = {
      agent_id: proofing_agent_id,
      location_id: proofing_location_id,
      correlation_id: correlation_id,
      transaction_id: transaction_id,
    }

    proofing_components = {
      document_check: document_capture_session.doc_auth_vendor,
      address_check: combined_result&.dig(
        :resolution, :context, :stages, :residential_address,
        :vendor_name
      ),
      resolution_check: combined_result&.dig(
        :resolution, :context, :stages, :resolution,
        :vendor_name
      ),
    }

    analytics.idv_doc_auth_verify_proofing_results(
      **{
        success:,
        proofing_agent: analytics_attributes,
        proofing_components:,
        analytics_id: 'Doc Auth',
        address_edited: false,
        address_line2_present: false,
        errors: combined_result&.dig(:resolution, :errors),
        last_name_spaced: combined_result&.dig(:pii, :last_name)&.include?(' '),
        opted_in_to_in_person_proofing: false,
        proofing_results: combined_result&.dig(:resolution),
        ssn_is_unique: combined_result&.dig(:resolution, :ssn_is_unique),
        step: 'Proofing Agent Job',
        flow_path: 'Proofing Agent',
      }.to_h.merge(
        pii_like_keypaths: [
          [:proofing_results, :biographical_info],
          [:proofing_results, :errors, :zipcode],
          [:proofing_results, :errors, :ssn],
          [:proofing_results, :biographical_info, :identity_doc_address_state],
          [:proofing_results, :biographical_info, :state_id_jurisdiction],
          [:proofing_results, :context, :stages, :resolution, :errors, :zipcode],
          [:proofing_results, :biographical_info, :same_address_as_id],
          [:proofing_results, :biographical_info, :phone],
          [:proofing_results, :context, :stages, :resolution, :errors, :ssn],
          [:errors, :zipcode],
          [:errors, :ssn],
        ],
      ),
    )

    if webhook_url.present?
      ProofingAgentWebhookJob.perform_later(
        success:,
        reason:,
        transaction_id:,
        correlation_id:,
        analytics_attributes: analytics_attributes.merge(proofing_components: proofing_components),
      )
    end

    if !success && final_attempt
      ProofingAgent::FailureEmailSender.new(user: user, analytics: analytics).call(
        visited_at: (document_capture_session.requested_at || Time.zone.now).iso8601,
        reason: reason,
        proofing_agent_id: proofing_agent_id,
        proofing_location_id: proofing_location_id,
        correlation_id: correlation_id,
        transaction_id: transaction_id,
      )
    end
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
    correlation_id:,
    transaction_id:,
    submit_attempts:,
    remaining_attempts:
  )
    aamva_result = nil

    analytics_attributes = {
      agent_id: proofing_agent_id,
      location_id: proofing_location_id,
      correlation_id: correlation_id,
      transaction_id: transaction_id,
    }
    if applicant_pii[:state_id_number].present?
      aamva_result = call_aamva_verification(
        applicant_pii:,
        current_sp:,
        timer:,
        analytics_attributes:,
      )
      applicant_pii[:aamva_verified_attributes] = aamva_result.verified_attributes if aamva_result
    end

    mrz_result = nil

    if applicant_pii[:mrz].present?
      mrz_result = call_mrz_verification(
        applicant_pii:,
        timer:,
      )

      analytics.idv_dos_passport_verification(
        success: mrz_result&.success?,
        submit_attempts:,
        remaining_submit_attempts: remaining_attempts,
        document_type_requested: Idp::Constants::DocumentTypes::PASSPORT,
        proofing_agent: analytics_attributes,
        correlation_id_sent: correlation_id,
        error_message: mrz_result&.errors&.dig(:passport),
        exception: mrz_result&.exception&.message,
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
      analytics_attributes:,
    )

    ProofingAgent::ProofingResult.new(
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      transaction_id:,
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
    proofing_vendor:,
    analytics_attributes:
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
        is_proofing_agent: true,
      )
    end

    proofing_result = DocumentCaptureSession.new(result_id:).load_proofing_result&.result

    phone_precheck_body = proofing_result&.dig(:context, :stages, :phone_precheck)
    phone_info = proofing_result&.dig(:biographical_info, :phone)

    proofing_components = {
      document_check: document_capture_session.doc_auth_vendor,
      address_check: proofing_result&.dig(:context, :stages, :residential_address, :vendor_name),
      resolution_check: proofing_result&.dig(:context, :stages, :resolution, :vendor_name),
    }

    analytics.idv_phone_confirmation_vendor_submitted(
      **{
        success: phone_precheck_body&.dig(:success),
        vendor: phone_precheck_body,
        area_code: phone_info&.dig(:area_code),
        country_code: phone_info&.dig(:country_code),
        phone_fingerprint: phone_info&.dig(:fingerprint),
        new_phone_added: true,
        hybrid_handoff_phone_used: false,
        manual_review: false,
        errors: phone_precheck_body&.dig(:errors),
        reason_codes: proofing_result&.dig(:context, :stages, :resolution, :reason_codes),
        proofing_agent: analytics_attributes,
        proofing_components:,
      }.to_h.merge(
        pii_like_keypaths: [
          [:errors, :phone],
        ],
      ),
    )

    proofing_result
  end

  def call_aamva_verification(applicant_pii:, current_sp:, timer:, analytics_attributes:)
    aamva_plugin.call(
      applicant_pii:,
      current_sp:,
      state_id_address_resolution_result: nil,
      ipp_enrollment_in_progress: false,
      timer:,
      doc_auth_flow: true,
      analytics:,
      proofing_agent_analytics_arguments: analytics_attributes,
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
