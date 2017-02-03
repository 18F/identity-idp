module Idv
  class ProfileStep < Step
    def submit
      initialize_idv_session

      @success = complete?

      increment_attempts_count if form_valid?
      update_idv_session

      FormResponse.new(success: success, errors: errors, extra: extra_analytics_attributes)
    end

    def attempts_exceeded?
      attempter.exceeded?
    end

    def duplicate_ssn?
      errors.key?(:ssn) && errors[:ssn].include?(I18n.t('idv.errors.duplicate_ssn'))
    end

    def form_valid_but_vendor_validation_failed?
      form_valid? && !vendor_validation_passed?
    end

    private

    attr_reader :success

    def initialize_idv_session
      idv_session.params.merge!(params)
      idv_session.applicant = vendor_params
    end

    def vendor_params
      idv_session.applicant_from_params
    end

    def complete?
      !attempts_exceeded? && form_valid? && vendor_validation_passed?
    end

    def attempter
      @_idv_attempter ||= Idv::Attempter.new(idv_form.user)
    end

    def increment_attempts_count
      attempter.increment
    end

    def form_valid?
      form_validate(params)[:success] == true
    end

    def vendor_validator_class
      Idv::ProfileValidator
    end

    def update_idv_session
      idv_session.profile_confirmation = success
      idv_session.resolution = vendor_validator.result
    end

    def extra_analytics_attributes
      {
        idv_attempts_exceeded: attempts_exceeded?,
        vendor: { reasons: vendor_reasons }
      }
    end

    def vendor_reasons
      vendor_validator.reasons if form_valid?
    end
  end
end
