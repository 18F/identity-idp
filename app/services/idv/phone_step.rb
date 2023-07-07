module Idv
  class PhoneStep
    def initialize(idv_session:, trace_id:, analytics:, attempts_tracker:)
      self.idv_session = idv_session
      @trace_id = trace_id
      @analytics = analytics
      @attempts_tracker = attempts_tracker
    end

    def submit(step_params)
      return rate_limited_result if rate_limiter.limited?
      rate_limiter.increment!

      self.step_params = step_params
      idv_session.previous_phone_step_params = step_params.slice(
        :phone, :international_code,
        :otp_delivery_preference
      )
      proof_address
    end

    def failure_reason
      return :fail if rate_limiter.limited?
      return :no_idv_result if idv_result.nil?
      return :timeout if idv_result[:timed_out]
      return :jobfail if idv_result[:exception].present?
      return :warning if idv_result[:success] != true
    end

    def async_state
      dcs_uuid = idv_session.idv_phone_step_document_capture_session_uuid
      dcs = DocumentCaptureSession.find_by(uuid: dcs_uuid)
      return ProofingSessionAsyncResult.none if dcs_uuid.nil?
      return missing if dcs.nil?

      proofing_job_result = dcs.load_proofing_result
      return missing if proofing_job_result.nil?

      proofing_job_result
    end

    def async_state_done(async_state)
      @idv_result = async_state.result

      success = idv_result[:success]
      handle_successful_proofing_attempt if success

      delete_async
      FormResponse.new(
        success: success, errors: idv_result[:errors],
        extra: extra_analytics_attributes
      )
    end

    private

    attr_accessor :idv_session, :step_params, :idv_result
    attr_reader :trace_id

    def proof_address
      return if idv_session.idv_phone_step_document_capture_session_uuid
      document_capture_session = DocumentCaptureSession.create(
        user_id: idv_session.current_user.id,
        requested_at: Time.zone.now,
      )

      idv_session.idv_phone_step_document_capture_session_uuid = document_capture_session.uuid

      run_job(document_capture_session)
    end

    def handle_successful_proofing_attempt
      update_idv_session
      start_phone_confirmation_session
    end

    def applicant
      @applicant ||= idv_session.applicant.merge(
        phone: normalized_phone,
        uuid_prefix: uuid_prefix,
      )
    end

    def uuid_prefix
      idv_session.service_provider&.app_id
    end

    def normalized_phone
      @normalized_phone ||= begin
        formatted_phone = PhoneFormatter.format(phone_param)
        formatted_phone.gsub(/\D/, '')[1..-1] if formatted_phone.present?
      end
    end

    def phone_param
      params = step_params || idv_session.previous_phone_step_params
      step_phone = params[:phone]
      if step_phone == 'other'
        params[:other_phone]
      else
        step_phone
      end
    end

    def otp_delivery_preference
      preference = idv_session.previous_phone_step_params[:otp_delivery_preference]
      return :sms if (preference.nil? || preference.empty?)
      preference.to_sym
    end

    def rate_limiter
      @rate_limiter ||= RateLimiter.new(
        user: idv_session.current_user,
        rate_limit_type: :proof_address,
      )
    end

    def rate_limited_result
      @attempts_tracker.idv_phone_otp_sent_rate_limited
      @analytics.throttler_rate_limit_triggered(throttle_type: :proof_address, step_name: :phone)
      FormResponse.new(success: false)
    end

    def failed_due_to_timeout_or_exception?
      idv_result[:timed_out] || idv_result[:exception]
    end

    def update_idv_session
      idv_session.address_verification_mechanism = :phone
      idv_session.applicant = applicant
      idv_session.vendor_phone_confirmation = true
      idv_session.user_phone_confirmation = false

      ProofingComponent.find_or_create_by(user: idv_session.current_user).
        update(address_check: 'lexis_nexis_address')
    end

    def start_phone_confirmation_session
      idv_session.user_phone_confirmation_session = Idv::PhoneConfirmationSession.start(
        phone: PhoneFormatter.format(applicant[:phone]),
        delivery_method: otp_delivery_preference,
      )
    end

    def extra_analytics_attributes
      parsed_phone = Phonelib.parse(applicant[:phone])

      {
        vendor: idv_result.except(:errors, :success),
        area_code: parsed_phone.area_code,
        country_code: parsed_phone.country,
        phone_fingerprint: Pii::Fingerprinter.fingerprint(parsed_phone.e164),
      }
    end

    def run_job(document_capture_session)
      Idv::Agent.new(applicant).proof_address(
        document_capture_session,
        trace_id: trace_id,
        issuer: idv_session.service_provider&.issuer,
        user_id: idv_session.current_user.id,
      )
    end

    def missing
      delete_async
      ProofingSessionAsyncResult.missing
    end

    def delete_async
      idv_session.idv_phone_step_document_capture_session_uuid = nil
    end
  end
end
