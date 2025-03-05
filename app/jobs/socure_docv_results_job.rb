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

    if docv_result_response.success?
      doc_pii_response = Idv::DocPiiForm.new(pii: docv_result_response.pii_from_doc.to_h).submit
      log_pii_validation(doc_pii_response:)

      unless doc_pii_response&.success?
        document_capture_session.store_failed_auth_data(
          doc_auth_success: true,
          selfie_status: docv_result_response.selfie_status,
          errors: { pii_validation: 'failed' },
          front_image_fingerprint: nil,
          back_image_fingerprint: nil,
          selfie_image_fingerprint: nil,
        )
        return
      end
    end
    document_capture_session.store_result_from_response(docv_result_response)
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

  def log_verification_request(docv_result_response:, vendor_request_time_in_ms:)
    analytics.idv_socure_verification_data_requested(
      **docv_result_response.to_h.merge(
        submit_attempts: rate_limiter&.attempts,
        remaining_submit_attempts: rate_limiter&.remaining_count,
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
        submit_attempts: rate_limiter&.attempts,
        remaining_submit_attempts: rate_limiter&.remaining_count,
        flow_path: nil,
        liveness_checking_required: nil,
      ),
    )
  end

  def socure_document_verification_result
    DocAuth::Socure::Requests::DocvResultRequest.new(
      document_capture_session_uuid:,
      docv_transaction_token_override:,
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
end
