module Idv
  class ProfileStep
    def initialize(idv_session:)
      self.idv_session = idv_session
    end

    def submit(step_params)
      consume_step_params(step_params)
      self.idv_result = Idv::Agent.new(applicant).proof_resolution(proof_state_id: true)
      Throttler::Increment.call(*idv_throttle_params) unless failed_due_to_timeout_or_exception?
      update_idv_session if success?
      FormResponse.new(
        success: success?, errors: idv_result[:errors],
        extra: extra_analytics_attributes
      )
    end

    def failure_reason
      return if success?
      return :fail if throttled?
      return :timeout if idv_result[:timed_out]
      return :jobfail if idv_result[:exception].present?
      :warning
    end

    private

    attr_accessor :idv_session, :step_params, :idv_result

    def throttled?
      Throttler::IsThrottled.call(*idv_throttle_params)
    end

    def consume_step_params(params)
      self.step_params = params.merge(state_id_jurisdiction: params[:state])
    end

    def applicant
      step_params.merge(uuid: idv_session.current_user.uuid, uuid_prefix: uuid_prefix)
    end

    def uuid_prefix
      ServiceProvider.from_issuer(idv_session.issuer).app_id
    end

    def idv_throttle_params
      [idv_session.current_user.id, :idv_resolution]
    end

    def success?
      idv_result[:success]
    end

    def failed_due_to_timeout_or_exception?
      idv_result[:timed_out] || idv_result[:exception]
    end

    def update_idv_session
      idv_session.applicant = applicant
      idv_session.profile_confirmation = true
      idv_session.resolution_successful = true
    end

    def extra_analytics_attributes
      {
        idv_attempts_exceeded: throttled?,
        vendor: idv_result.except(:errors, :success),
      }
    end
  end
end
