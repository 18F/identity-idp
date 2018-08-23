module Idv
  class ProfileStep
    def initialize(idv_session:)
      self.idv_session = idv_session
    end

    def submit(step_params)
      consume_step_params(step_params)
      self.idv_result = Idv::Agent.new(step_params).proof(:resolution, :state_id)
      increment_attempts_count
      success = idv_result[:success]
      update_idv_session if success
      FormResponse.new(
        success: success, errors: idv_result[:errors],
        extra: extra_analytics_attributes
      )
    end

    def failure_reason
      return :fail if attempter.exceeded?
      return :jobfail if idv_result[:exception].present?
      return :warning if idv_result[:success] != true
    end

    private

    attr_accessor :idv_session, :step_params, :idv_result

    def consume_step_params(params)
      self.step_params = params.merge!(state_id_jurisdiction: params[:state])
    end

    def increment_attempts_count
      attempter.increment
    end

    def attempter
      @attempter ||= Idv::Attempter.new(idv_session.current_user)
    end

    def update_idv_session
      idv_session.applicant.merge!(step_params)
      idv_session.profile_confirmation = true
      idv_session.resolution_successful = true
    end

    def extra_analytics_attributes
      idv_result.except(:errors, :success)
    end

    # def submit
    #   @success = complete?
    #
    #   increment_attempts_count
    #   update_idv_session if success
    #
    #   FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    # end
    #
    # def attempts_exceeded?
    #   attempter.exceeded?
    # end
    #
    # private
    #
    # attr_reader :success
    #
    # def complete?
    #   !attempts_exceeded? && vendor_validation_passed?
    # end
    #
    # def attempter
    #   @_idv_attempter ||= Idv::Attempter.new(idv_session.current_user)
    # end
    #
    # def increment_attempts_count
    #   attempter.increment
    # end
    #
    # def update_idv_session
    #   idv_session.profile_confirmation = true
    #   idv_session.resolution_successful = true
    # end
    #
    # def extra_analytics_attributes
    #   {
    #     idv_attempts_exceeded: attempts_exceeded?,
    #     vendor: {
    #       messages: vendor_validator_result.messages,
    #       context: vendor_validator_result.context,
    #       exception: vendor_validator_result.exception,
    #     },
    #   }
    # end
  end
end
