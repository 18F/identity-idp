module Idv
  class PhoneStep
    def initialize(idv_session:, trace_id:)
      Rails.logger.info('DEBUG: entering Idv::PhoneStep#initialize')
      Rails.logger.info { "DEBUG: idv_session = #{idv_session.inspect}" } # TODO: important, contains @user_session, @current_user, see below
      Rails.logger.info { "DEBUG: trace_id = #{trace_id}" }               # empty, hmm?

      self.idv_session = idv_session
      @trace_id = trace_id
    end

    # idv_session = #<Idv::Session:0x00007f1db0af01e8
    #   @user_session={"need_two_factor_authentication"=>false, "unique_session_id"=>"xjPRDXx6ieDqWuA3VsHk", "last_request_at"=>1663707073,
    #     "auth_method"=>"backup_code", "authn_at"=>"2022-09-20 20:50:24 UTC", "context"=>"authentication", "created_at"=>"2022-09-20 20:50:24 UTC",
    #     "reactivate_account"=>{"active"=>false, "validated_personal_key"=>false, "x509"=>nil},
    #     "idv/inherited_proofing"=>{"error_message"=>nil, "Idv::Steps::InheritedProofing::GetStartedStep"=>true,
    #       "pii_from_user"=>{"phone"=>"303-555-1212"},
    #       "Idv::Steps::InheritedProofing::AgreementStep"=>true, "Idv::Steps::InheritedProofing::VerifyInfoStep"=>true},
    #     "idv"=>{"profile_confirmation"=>true, "vendor_phone_confirmation"=>false, "user_phone_confirmation"=>false,
    #     " address_verification_mechanism"=>"phone", "resolution_successful"=>"phone",
    #       "applicant"=>{"first_name"=>"Jake", "last_name"=>"Jabs", "uuid"=>"c7f83167-bce2-4d20-b10a-f0e2b5355ac1"}}},
    #   @current_user=#<User id: 10, created_at: "2022-09-05 23:01:43" ...

    def submit(step_params)
      self.step_params = step_params
      idv_session.previous_phone_step_params = step_params.slice(:phone)
      proof_address
    end

    def failure_reason
      return :fail if throttle.throttled?
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

      throttle.increment! unless failed_due_to_timeout_or_exception?
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

    def throttle
      @throttle ||= Throttle.new(user: idv_session.current_user, throttle_type: :proof_address)
    end

    def failed_due_to_timeout_or_exception?
      idv_result[:timed_out] || idv_result[:exception]
    end

    def update_idv_session
      idv_session.address_verification_mechanism = :phone
      idv_session.applicant = applicant
      idv_session.vendor_phone_confirmation = true
      idv_session.user_phone_confirmation = false

      ProofingComponent.create_or_find_by(user: idv_session.current_user).
        update(address_check: 'lexis_nexis_address')
    end

    def start_phone_confirmation_session
      idv_session.user_phone_confirmation_session = PhoneConfirmation::ConfirmationSession.start(
        phone: PhoneFormatter.format(applicant[:phone]),
        delivery_method: :sms,
      )
    end

    def extra_analytics_attributes
      {
        vendor: idv_result.except(:errors, :success),
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
