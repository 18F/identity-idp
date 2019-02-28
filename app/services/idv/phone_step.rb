module Idv
  class PhoneStep
    def initialize(idv_session:)
      self.idv_session = idv_session
    end

    def submit(step_params)
      self.step_params = step_params
      self.idv_result = Idv::Agent.new(applicant).proof(:address)
      increment_attempts_count unless failed_due_to_timeout_or_exception?
      success = idv_result[:success]
      update_idv_session if success
      FormResponse.new(
        success: success, errors: idv_result[:errors],
        extra: extra_analytics_attributes
      )
    end

    def failure_reason
      return :fail if idv_session.step_attempts[:phone] >= Idv::Attempter.idv_max_attempts
      return :timeout if idv_result[:timed_out]
      return :jobfail if idv_result[:exception].present?
      return :warning if idv_result[:success] != true
    end

    private

    attr_accessor :idv_session, :step_params, :idv_result

    def applicant
      @applicant ||= idv_session.applicant.merge(
        phone: normalized_phone,
      )
    end

    def normalized_phone
      @normalized_phone ||= begin
        formatted_phone = PhoneFormatter.format(phone_param)
        formatted_phone.gsub(/\D/, '')[1..-1] if formatted_phone.present?
      end
    end

    def phone_param
      step_phone = step_params[:phone]
      if step_phone == 'other'
        step_params[:other_phone]
      else
        step_phone
      end
    end

    def increment_attempts_count
      idv_session.step_attempts[:phone] += 1
    end

    def failed_due_to_timeout_or_exception?
      idv_result[:timed_out] || idv_result[:exception]
    end

    def update_idv_session
      idv_session.address_verification_mechanism = :phone
      idv_session.applicant = applicant
      idv_session.vendor_phone_confirmation = true
      idv_session.user_phone_confirmation = phone_matches_user_phone?
    end

    def phone_matches_user_phone?
      applicant_phone = PhoneFormatter.format(applicant[:phone])
      return false if applicant_phone.blank?
      user_phones.include?(applicant_phone)
    end

    def user_phones
      MfaContext.new(
        idv_session.current_user,
      ).phone_configurations.map do |phone_configuration|
        PhoneFormatter.format(phone_configuration.phone)
      end.compact
    end

    def extra_analytics_attributes
      {
        vendor: idv_result.except(:errors, :success),
      }
    end
  end
end
