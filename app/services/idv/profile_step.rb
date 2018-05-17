module Idv
  class ProfileStep < Step
    def submit
      @success = complete?

      increment_attempts_count
      update_idv_session if success

      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    end

    def attempts_exceeded?
      attempter.exceeded?
    end

    private

    attr_reader :success

    def complete?
      !attempts_exceeded? && vendor_validation_passed?
    end

    def attempter
      @_idv_attempter ||= Idv::Attempter.new(idv_session.current_user)
    end

    def increment_attempts_count
      attempter.increment
    end

    def update_idv_session
      idv_session.profile_confirmation = true
      idv_session.resolution_successful = true
    end

    def extra_analytics_attributes
      {
        idv_attempts_exceeded: attempts_exceeded?,
        vendor: {
          messages: vendor_validator_result.messages,
          context: vendor_validator_result.context,
          exception: vendor_validator_result.exception,
        },
      }
    end
  end
end
