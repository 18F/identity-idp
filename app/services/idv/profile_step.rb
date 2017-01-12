module Idv
  class ProfileStep < Step
    def complete?
      idv_session.resolution.try(:success?) ? true : false
    end

    def complete
      return track_event if attempts_exceeded?
      idv_session.params.merge!(params)
      vendor_validate if form_validate(params)[:success]
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

    def vendor_params
      idv_session.applicant_from_params
    end

    def vendor_validate
      result = vendor_validator.validate
      attempter.increment
      result
    end

    def vendor_validator_class
      Idv::ProfileValidator
    end

    def vendor_errors
      idv_session.resolution.try(:errors)
    end

    def analytics_result
      {
        success: complete?,
        idv_attempts_exceeded: attempts_exceeded?,
        errors: errors
      }
    end

    def analytics_event
      Analytics::IDV_BASIC_INFO_SUBMITTED
    end
  end
end
