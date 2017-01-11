module Idv
  class ProfileStep < Step
    def complete?
      idv_session.resolution.try(:success?) ? true : false
    end

    def complete
      return if attempts_exceeded?
      idv_session.params.merge!(params)
      validate(params)
      confirm if form_result[:success]
      track_event
      complete?
    end

    def attempts_exceeded?
      attempter.exceeded?
    end

    private

    def attempter
      @_idv_attempter ||= Idv::Attempter.new(idv_form.user)
    end

    def confirm
      idv_session.applicant = idv_session.applicant_from_params
      idv_session.vendor = idv_agent.vendor
      idv_session.resolution = idv_agent.start(idv_session.applicant)
      attempter.increment
    end

    def vendor_errors
      idv_session.resolution.try(:errors)
    end

    def track_event
      result = {
        success: complete?,
        idv_attempts_exceeded: attempts_exceeded?,
        errors: errors
      }

      analytics.track_event(Analytics::IDV_BASIC_INFO_SUBMITTED, result)
    end
  end
end
