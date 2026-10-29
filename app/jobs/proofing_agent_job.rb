# frozen_string_literal: true

class ProofingAgentJob < ApplicationJob
  include JobHelpers::StaleJobHelper
  include AbTestingConcern
  include ProofingAgent::Config

  queue_as :high_proofing_agent

  # PA can submit a residential and a document address, so we always verify both (dual
  # address verification), the same as IPP. AAMVA and resolution must use this same value
  # so they verify the same (document) address and a verified AAMVA :address cannot cover
  # a resolution failure for an address it never saw.
  PA_BEHAVES_LIKE_IPP = true

  SYSTEM_ERROR_REASON = 'system_error'

  STORAGE_CONNECTION_ERRORS = [Redis::BaseConnectionError, ActiveRecord::StatementInvalid].freeze

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  attr_reader :document_capture_session, :proofing_components, :proofing_agent,
              :failure_email_users, :reminder_email_users

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

    @proofing_agent = {
      agent_id: proofing_agent_id,
      location_id: proofing_location_id,
      correlation_id: correlation_id,
      transaction_id: transaction_id,
    }
    @proofing_components = {}
    @failure_email_users = Idv::ProofingAgent::FailureEmailUserSet.new
    @reminder_email_users = Idv::ProofingAgent::ReminderEmailUserSet.new
    webhook_enqueued = false

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

    if combined_result&.dig(:success)
      proofing_components[:document_check] = Idp::Constants::Vendors::PROOFING_AGENT
    end

    store_agent_proofed_user_to_document_capture_session(
      result: proofing_result.combined_result,
      transaction_id:,
    )

    success = combined_result[:success]
    reason = combined_result[:reason]

    log_attempt(
      user_id: user.id, success:, pii: applicant_pii, transaction_id:, failure_reason: reason,
    )

    if success
      failure_email_users.remove(user.uuid)
      verified_at = document_capture_session.load_agent_proofed_user&.verified_at
      ProofingAgent::SuccessEmailSender.new(
        user: user, analytics: analytics,
        service_provider: current_sp
      ).call(
        verified_at: verified_at,
        proofing_agent_id: proofing_agent_id,
        proofing_location_id: proofing_location_id,
        correlation_id: correlation_id,
        transaction_id: transaction_id,
      )
      # Queue a reminder email for the user if they have not confirmed their account; only
      # when the confirmation email was actually sent (verified_at present).
      reminder_email_users.add(user.uuid) if verified_at.present?
    elsif final_attempt
      failure_email_users.remove(user.uuid)
      ProofingAgent::FailureEmailSender.new(user: user, analytics: analytics).call(
        visited_at: (document_capture_session.requested_at || Time.zone.now).iso8601,
        reason: reason,
        proofing_agent_id: proofing_agent_id,
        proofing_location_id: proofing_location_id,
        correlation_id: correlation_id,
        transaction_id: transaction_id,
      )
    else
      failure_email_users.add(user.uuid)
    end
    if webhook_url.present?
      ProofingAgentWebhookJob.perform_later(
        success:,
        reason:,
        transaction_id:,
        correlation_id:,
        analytics_attributes: {
          proofing_agent:,
          proofing_components:,
        },
      )
      webhook_enqueued = true
    end
  rescue StandardError => e
    unless STORAGE_CONNECTION_ERRORS.include?(e.class)
      store_agent_proofed_user_to_document_capture_session(
        result: failed_proofing_result,
        transaction_id:,
      )
    end

    if document_capture_session.present? && applicant_pii.present?
      log_attempt(
        user_id: user.id,
        success: false,
        pii: applicant_pii,
        transaction_id:,
        failure_reason: SYSTEM_ERROR_REASON,
      )
    end

    notify_system_error(source: 'unexpected', exception: e, transaction_id:)
    unless webhook_enqueued
      enqueue_system_error_webhook(transaction_id:, correlation_id:)
    end
    raise
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
    @proofing_exception_occurred = false

    aamva_result = nil

    if applicant_pii[:state_id_number].present?
      aamva_result = with_vendor_error_handling(source: 'aamva', transaction_id:) do
        call_aamva_verification(
          applicant_pii:,
          current_sp:,
          timer:,
        )
      end
      applicant_pii[:aamva_verified_attributes] = aamva_result.verified_attributes if aamva_result
      if aamva_result&.success?
        proofing_components[:source_check] = aamva_result.to_h[:vendor_name]
      end
    end

    mrz_result = nil

    if applicant_pii[:mrz].present?
      mrz_result = with_vendor_error_handling(source: 'mrz', transaction_id:) do
        call_mrz_verification(
          applicant_pii:,
          timer:,
        )
      end

      analytics.idv_dos_passport_verification(
        success: mrz_result&.success?,
        submit_attempts:,
        remaining_submit_attempts: remaining_attempts,
        document_type_requested: Idp::Constants::DocumentTypes::PASSPORT,
        category: mrz_result&.extra&.dig(:category),
        proofing_agent:,
        correlation_id_sent: correlation_id,
        error_message: mrz_result&.errors&.dig(:passport),
        exception: mrz_result&.exception&.message,
      )

      if mrz_result&.success? == true
        proofing_components[:source_check] = mrz_result.to_h[:vendor_name]
      end
    end

    # Only call the proofing vendors once the ID has been validated (AAMVA or DoS/MRZ).
    # If the relevant source check was unsuccessful, skip resolution entirely so we
    # don't spend on the resolution/phone vendors or log their events.
    source_check_succeeded = aamva_result&.success? || mrz_result&.success?

    resolution_result = nil

    if source_check_succeeded
      re_encrypted_arguments = Encryption::Encryptors::BackgroundProofingArgEncryptor.new.encrypt(
        { applicant_pii: }.to_json,
      )

      resolution_result = with_vendor_error_handling(source: 'resolution', transaction_id:) do
        call_resolution_proofing_job(
          timer:,
          result_id: SecureRandom.uuid,
          encrypted_arguments: re_encrypted_arguments,
          trace_id:,
          user_id: user.id,
          service_provider_issuer:,
          proofing_vendor:,
        )
      end

      if resolution_result&.dig(:context, :stages, :resolution, :success) == true
        proofing_components[:residential_resolution_check] = resolution_result&.dig(
          :context, :stages, :residential_address, :vendor_name
        )
        proofing_components[:resolution_check] = resolution_result&.dig(
          :context, :stages, :resolution, :vendor_name
        )
      end

      if resolution_result&.dig(:context, :stages, :phone_precheck, :success) == true
        proofing_components[:address_check] = resolution_result&.dig(
          :context, :stages, :phone_precheck, :vendor_name
        )
      end

      analytics.idv_doc_auth_verify_proofing_results(
        **{
          success: resolution_result&.dig(:context, :stages, :resolution, :success) || false,
          proofing_agent:,
          proofing_components: proofing_components.dup,
          analytics_id: 'Doc Auth',
          address_edited: false,
          address_line2_present: false,
          errors: resolution_result&.dig(:errors),
          last_name_spaced: applicant_pii&.dig(:last_name)&.include?(' '),
          opted_in_to_in_person_proofing: false,
          proofing_results: resolution_result&.to_h,
          ssn_is_unique: resolution_result&.dig(:ssn_is_unique),
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
            [:proofing_results, :biographical_info, :ipp_current_address_matches_id],
            [:proofing_results, :biographical_info, :phone],
            [:proofing_results, :context, :stages, :resolution, :errors, :ssn],
            [:proofing_results, :context, :stages, :residential_address, :errors, :zipcode],
            [:proofing_results, :context, :stages, :residential_address, :errors, :ssn],
            [:errors, :zipcode],
            [:errors, :ssn],
          ],
        ),
      )

      if resolution_result&.dig(:context, :stages, :phone_precheck).present?
        phone_precheck_body = resolution_result&.dig(:context, :stages, :phone_precheck)
        phone_info = resolution_result&.dig(:biographical_info, :phone)

        analytics.idv_phone_confirmation_vendor_submitted(
          **{
            success: phone_precheck_body&.dig(:success),
            vendor: phone_precheck_body,
            area_code: phone_info&.dig(:area_code),
            country_code: phone_info&.dig(:country_code),
            phone_fingerprint: phone_info&.dig(:phone_fingerprint),
            new_phone_added: true,
            hybrid_handoff_phone_used: false,
            manual_review: false,
            errors: phone_precheck_body&.dig(:errors),
            reason_codes: phone_precheck_body&.dig(:reason_codes),
            proofing_agent:,
            proofing_components: proofing_components.dup,
          }.to_h.merge(
            pii_like_keypaths: [
              [:errors, :phone],
            ],
          ),
        )
      end
    end

    ProofingAgent::ProofingResult.new(
      proofing_agent_id:,
      proofing_location_id:,
      correlation_id:,
      transaction_id:,
      pii: applicant_pii,
      resolution_result:,
      aamva_result:,
      mrz_result:,
      system_error: (
        @proofing_exception_occurred || (source_check_succeeded && resolution_result.nil?)
      ) ? SYSTEM_ERROR_REASON : nil,
      service_provider_issuer:,
    )
  end

  def with_vendor_error_handling(source:, transaction_id:)
    yield
  rescue StandardError => e
    @proofing_exception_occurred = true
    notify_system_error(source:, exception: e, transaction_id:)
    nil
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
        ipp_enrollment_in_progress: PA_BEHAVES_LIKE_IPP,
        proofing_vendor:,
        is_proofing_agent: true,
      )
    end

    DocumentCaptureSession.new(result_id:).load_proofing_result&.result
  end

  def call_aamva_verification(applicant_pii:, current_sp:, timer:)
    aamva_verifier.call(
      applicant_pii:,
      current_sp:,
      ipp_enrollment_in_progress: PA_BEHAVES_LIKE_IPP,
      timer:,
      analytics:,
      analytics_arguments: {
        proofing_agent:,
      },
    )
  end

  def call_mrz_verification(applicant_pii:, timer:)
    mrz = applicant_pii[:mrz]
    return nil if mrz.blank?

    mrz_client = if IdentityConfig.store.proofer_mock_fallback
                   DocAuth::Mock::DosPassportApiClient.new
                 else
                   DocAuth::Dos::Requests::MrzRequest.new(
                     mrz:,
                     id_type: applicant_pii[:document_type_received],
                   )
                 end

    timer.time('mrz') { mrz_client.fetch }
  end

  def proofing_vendor
    @proofing_vendor ||= begin
      # if proofing vendor A/B test is disabled, return default vendor
      vendor = ab_test_bucket(
        :PROOFING_AGENT_PROOFING_VENDOR,
        user:,
        service_provider: service_provider_issuer,
        current_session: nil,
        current_user_session: nil,
      )

      vendor || IdentityConfig.store.idv_resolution_default_vendor
    end
  end

  def aamva_verifier
    @aamva_verifier ||= DocAuth::Aamva::Verifier.new
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

  def failed_proofing_result
    ProofingAgent::ProofingResult.new(
      proofing_agent_id: proofing_agent[:agent_id],
      proofing_location_id: proofing_agent[:location_id],
      correlation_id: proofing_agent[:correlation_id],
      transaction_id: proofing_agent[:transaction_id],
      resolution_result: nil,
      service_provider_issuer: nil,
      pii: nil,
    ).failed_result
  end

  def store_agent_proofed_user_to_document_capture_session(result:, transaction_id:)
    document_capture_session&.store_agent_proofed_user(result)
  rescue *STORAGE_CONNECTION_ERRORS => e
    logger_info_hash(
      name: 'ProofingAgent',
      reason: SYSTEM_ERROR_REASON,
      error: e.message,
      transaction_id:,
    )
    raise
  end

  def notify_system_error(source:, exception:, transaction_id:)
    logger_info_hash(
      name: 'ProofingAgent',
      reason: SYSTEM_ERROR_REASON,
      source:,
      error: exception.message,
      transaction_id:,
    )

    NewRelic::Agent.notice_error(
      exception,
      custom_params: {
        event: 'ProofingAgent proofing attempt failed',
        source:,
        transaction_id:,
      },
    )
  end

  def enqueue_system_error_webhook(transaction_id:, correlation_id:)
    return if webhook_url.blank?

    ProofingAgentWebhookJob.perform_later(
      success: false,
      reason: SYSTEM_ERROR_REASON,
      transaction_id:,
      correlation_id:,
      analytics_attributes: {
        proofing_agent: proofing_agent || {},
        proofing_components: proofing_components || {},
      },
    )
  end

  def user
    @user ||= document_capture_session&.user
  end

  def service_provider_issuer
    document_capture_session&.issuer
  end

  def result_id
    document_capture_session&.result_id
  end

  def service_provider
    ServiceProvider.find_by(issuer: service_provider_issuer)
  end

  def attempts_api_tracker
    AttemptsApi::Tracker.new(
      enabled_for_session: service_provider.attempts_api_enabled?,
      session_id: nil,
      request: nil,
      user:,
      sp: service_provider,
      cookie_device_uuid: nil,
      sp_redirect_uri: nil,
    )
  end

  def log_attempt(user_id:, success:, pii:, transaction_id:, failure_reason:)
    attempts_api_tracker.idv_proofing_agent_verification_submitted(
      user_id:,
      success:,
      transaction_id:,
      pii: {
        first_name: pii[:first_name],
        last_name: pii[:last_name],
        date_of_birth: pii[:dob],
        ssn: SsnFormatter.format(pii[:ssn]),
        address_1: pii[:address1],
        address_2: pii[:address2],
        city: pii[:city],
        state: pii[:state],
        zip: pii[:zipcode],
        phone: pii[:phone],
        **document_pii(pii),
      },
      failure_reason:,
    )
  end

  def document_pii(pii)
    if pii[:document_type_received] == Idp::Constants::DocumentTypes::PASSPORT
      passport_document_pii(pii)
    else
      state_id_document_pii(pii)
    end
  end

  def passport_document_pii(pii)
    {
      document_type: pii[:document_type_received],
      document_number: pii[:document_number],
      document_expiration: pii[:passport_expiration],
      document_issued: pii[:passport_issued],
    }
  end

  def state_id_document_pii(pii)
    {
      document_type: pii[:document_type_received],
      document_state_jurisdiction: pii[:state_id_jurisdiction],
      document_number: pii[:state_id_number],
      document_expiration: pii[:state_id_expiration],
      document_issued: pii[:state_id_issued],
      document_address_1: pii[:identity_doc_address1],
      document_address_2: pii[:identity_doc_address2],
      document_city: pii[:identity_doc_address_city],
      document_state: pii[:identity_doc_address_state],
      document_zip: pii[:identity_doc_address_zipcode],
    }
  end
end
