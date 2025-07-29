# frozen_string_literal: true

class SocureDocvResultsJob < ApplicationJob
  queue_as :high_socure_docv

  attr_reader :document_capture_session_uuid, :async, :docv_transaction_token_override

  # @param [String] document_capture_session_uuid
  def perform(document_capture_session_uuid:, async: true, docv_transaction_token_override: nil)
    @document_capture_session_uuid = document_capture_session_uuid
    @async = async
    @docv_transaction_token_override = docv_transaction_token_override

    raise "DocumentCaptureSession not found: #{document_capture_session_uuid}" unless
      document_capture_session

    timer = JobHelpers::Timer.new
    docv_result_response = timer.time('vendor_request') do
      socure_document_verification_result
    end

    log_verification_request(
      docv_result_response:,
      vendor_request_time_in_ms: timer.results['vendor_request'],
    )

    # for ipp enrollment to track if user attempted doc auth
    last_doc_auth_result = docv_result_response.extra_attributes.dig(:decision, :value)
    document_capture_session.update!(last_doc_auth_result:) if last_doc_auth_result

    unless docv_result_response.success?
      document_capture_session.store_failed_auth_data(
        doc_auth_success: docv_result_response.doc_auth_success?,
        selfie_status: docv_result_response.selfie_status,
        errors: docv_result_response.errors,
        front_image_fingerprint: nil,
        back_image_fingerprint: nil,
        passport_image_fingerprint: nil,
        selfie_image_fingerprint: nil,
      )

      record_attempt(docv_result_response:)
      return
    end

    doc_pii_response = Idv::DocPiiForm.new(pii: docv_result_response.pii_from_doc.to_h).submit
    log_pii_validation(doc_pii_response:)

    unless doc_pii_response&.success?
      document_capture_session.store_failed_auth_data(
        doc_auth_success: true,
        selfie_status: docv_result_response.selfie_status,
        errors: { pii_validation: 'failed' },
        front_image_fingerprint: nil,
        back_image_fingerprint: nil,
        passport_image_fingerprint: nil,
        selfie_image_fingerprint: nil,
      )
      record_attempt(docv_result_response:, doc_pii_response:)
      return
    end

    mrz_response = validate_mrz(doc_pii_response)
    if mrz_response && !mrz_response.success?
      document_capture_session.store_failed_auth_data(
        doc_auth_success: true,
        selfie_status: docv_result_response.selfie_status,
        errors: mrz_response.errors,
        front_image_fingerprint: nil,
        back_image_fingerprint: nil,
        passport_image_fingerprint: nil,
        selfie_image_fingerprint: nil,
        mrz_status: :failed,
      )
      record_attempt(docv_result_response:, doc_pii_response:)
      return
    end

    record_attempt(docv_result_response:, doc_pii_response:)
    document_capture_session.store_result_from_response(docv_result_response, mrz_response:)
  end

  private

  def record_attempt(docv_result_response:, doc_pii_response: nil)
    image_errors = {}

    if socure_doc_escrow_enabled? &&
       docv_result_response.instance_of?(DocAuth::Socure::Responses::DocvResultResponse)
      front = {
        document_front_image_file_id: doc_escrow_name,
        document_front_image_encryption_key: doc_escrow_key,
      }
      back = {
        document_back_image_file_id: doc_escrow_name,
        document_back_image_encryption_key: doc_escrow_key,
      }

      image_storage_data = { front:, back: }

      if docv_result_response.liveness_enabled
        selfie = {
          document_selfie_image_file_id: doc_escrow_name,
          document_selfie_image_encryption_key: doc_escrow_key,
        }
        image_storage_data[:selfie] = selfie
      end

      job_data = {
        document_capture_session_uuid:,
        reference_id: docv_result_response.to_h[:reference_id],
        image_storage_data:,
      }

      if IdentityConfig.store.ruby_workers_idv_enabled
        SocureImageRetrievalJob.perform_later(**job_data)
      else
        SocureImageRetrievalJob.perform_now(**job_data)
      end
    end

    pii_from_doc = docv_result_response.pii_from_doc.to_h || {}

    attempts_api_tracker.idv_document_upload_submitted(
      **front,
      **back,
      **selfie,
      success: docv_result_response.success? && doc_pii_response.success?,
      document_state: pii_from_doc[:state],
      document_number: pii_from_doc[:state_id_number],
      document_issued: pii_from_doc[:state_id_issued],
      document_expiration: pii_from_doc[:state_id_expiration],
      first_name: pii_from_doc[:first_name],
      last_name: pii_from_doc[:last_name],
      date_of_birth: pii_from_doc[:dob],
      address1: pii_from_doc[:address1],
      address2: pii_from_doc[:address2],
      city: pii_from_doc[:city],
      state: pii_from_doc[:state],
      zip: pii_from_doc[:zipcode],
      failure_reason: failure_reason(docv_result_response:, doc_pii_response:, image_errors:),
    )
  end

  def failure_reason(docv_result_response:, image_errors:, doc_pii_response: nil)
    if doc_pii_response.present?
      failures = attempts_api_tracker.parse_failure_reason(doc_pii_response) || {}
    else
      failures = attempts_api_tracker.parse_failure_reason(docv_result_response) || {}
      failures = failures[:socure].presence || failures || {}
    end

    failures.merge(image_errors).presence
  end

  def analytics
    @analytics ||= Analytics.new(
      user: document_capture_session.user,
      request: nil,
      session: {},
      sp: document_capture_session.issuer,
    )
  end

  def attempts_api_tracker
    @attempts_api_tracker ||= AttemptsApi::Tracker.new(
      session_id: nil,
      request: nil,
      user: document_capture_session.user,
      sp:,
      cookie_device_uuid: nil,
      sp_request_uri: nil,
      enabled_for_session: sp&.attempts_api_enabled?,
    )
  end

  def log_verification_request(docv_result_response:, vendor_request_time_in_ms:)
    analytics.idv_socure_verification_data_requested(
      **docv_result_response.to_h.merge(
        submit_attempts:,
        remaining_submit_attempts:,
        vendor_request_time_in_ms:,
        async:,
        pii_like_keypaths: [[:pii]],
      ).except(:attention_with_barcode, :selfie_live, :selfie_quality_good,
               :selfie_status),
    )
  end

  def log_pii_validation(doc_pii_response:)
    analytics.idv_doc_auth_submitted_pii_validation(
      **doc_pii_response.to_h.merge(
        submit_attempts:,
        remaining_submit_attempts:,
        flow_path: nil,
        liveness_checking_required: nil,
      ),
    )
  end

  def socure_document_verification_result
    DocAuth::Socure::Requests::DocvResultRequest.new(
      customer_user_id: user_uuid,
      document_capture_session_uuid:,
      docv_transaction_token_override:,
      user_email: document_capture_session&.user&.last_sign_in_email_address&.email,
    ).fetch
  end

  def fetch_images(reference_id)
    DocAuth::Socure::Requests::ImagesRequest.new(
      reference_id:,
    ).fetch
  end

  def document_capture_session
    @document_capture_session ||=
      DocumentCaptureSession.find_by(uuid: document_capture_session_uuid)
  end

  def rate_limiter
    @rate_limiter ||= RateLimiter.new(
      user: document_capture_session.user,
      rate_limit_type: :idv_doc_auth,
    )
  end

  def sp
    @sp ||= ServiceProvider.find_by(issuer: document_capture_session.issuer)
  end

  def socure_doc_escrow_enabled?
    sp&.attempts_api_enabled? && IdentityConfig.store.socure_doc_escrow_enabled
  end

  def doc_escrow_name
    SecureRandom.uuid
  end

  def doc_escrow_key
    Base64.strict_encode64(SecureRandom.bytes(32))
  end

  def validate_mrz(doc_pii_response)
    id_type = doc_pii_response.extra[:id_doc_type]
    unless id_type == 'passport'
      return unless document_capture_session.passport_requested?
    end

    mrz_client = Rails.env.development? ?
                    DocAuth::Mock::DosPassportApiClient.new :
                    DocAuth::Dos::Requests::MrzRequest.new(mrz: doc_pii_response.pii_from_doc[:mrz])
    response = mrz_client.fetch

    analytics.idv_dos_passport_verification(
      document_type:,
      remaining_submit_attempts:,
      submit_attempts:,
      user_id: user_uuid,
      success: response.success?,
      errors: response.errors.to_h,
      **response.extra.slice(
        :response, :correlation_id_sent, :correlation_id_received,
        :error_code, :error_message, :error_reason, :exception
      ),
    )

    response
  end

  def document_type
    @document_type ||= document_capture_session.passport_requested? \
      ? 'Passport' : 'DriversLicense'
  end

  def user_uuid
    @user_uuid ||= document_capture_session.user&.uuid
  end

  def submit_attempts
    rate_limiter&.attempts
  end

  def remaining_submit_attempts
    rate_limiter&.remaining_count
  end
end
