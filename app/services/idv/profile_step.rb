module Idv
  class ProfileStep
    def initialize(idv_session:)
      self.idv_session = idv_session
    end

    def submit(step_params)
      consume_step_params(step_params)
      self.idv_result = Idv::Agent.new(applicant).proof(:resolution, :state_id)
      increment_attempts_count unless failed_due_to_timeout_or_exception?
      update_idv_session if success?
      FormResponse.new(
        success: success?, errors: idv_result[:errors],
        extra: extra_analytics_attributes
      )
    end

    def failure_reason
      return if success?
      return :fail if attempter.exceeded?
      return :timeout if idv_result[:timed_out]
      return :jobfail if idv_result[:exception].present?
      :warning
    end

    private

    attr_accessor :idv_session, :step_params, :idv_result

    def consume_step_params(params)
      self.step_params = params.merge(state_id_jurisdiction: params[:state])
    end

    def applicant
      step_params.merge(uuid: idv_session.current_user.uuid)
    end

    def increment_attempts_count
      attempter.increment
    end

    def success?
      idv_result[:success] && ssn_is_unique?
    end

    def ssn_is_unique?
      ssn = applicant[:ssn]
      return false if ssn.nil?

      @ssn_is_unique ||= DuplicateSsnFinder.new(
        ssn: ssn, user: idv_session.current_user,
      ).ssn_is_unique?
    end

    def failed_due_to_timeout_or_exception?
      idv_result[:timed_out] || idv_result[:exception]
    end

    def attempter
      @attempter ||= Idv::Attempter.new(idv_session.current_user)
    end

    def update_idv_session
      idv_session.applicant = applicant
      idv_session.profile_confirmation = true
      idv_session.resolution_successful = true
    end

    def extra_analytics_attributes
      {
        idv_attempts_exceeded: attempter.exceeded?,
        vendor: idv_result.except(:errors, :success),
        ssn_is_unique: ssn_is_unique?,
      }
    end
  end
end
