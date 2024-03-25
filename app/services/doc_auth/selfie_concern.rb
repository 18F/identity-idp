module DocAuth
  module SelfieConcern
    extend ActiveSupport::Concern
    def selfie_live?
      portait_error = get_portrait_error(portrait_match_results)
      return true if portait_error.nil? || portait_error.blank?
      return !error_is_not_live(portait_error)
    end

    def selfie_quality_good?
      portait_error = get_portrait_error(portrait_match_results)
      return true if portait_error.nil? || portait_error.blank?
      return !error_is_poor_quality(portait_error)
    end

    def error_is_success(error_message)
      error_message == ERROR_TEXTS[:success]
    end

    def error_is_not_live(error_message)
      return error_message == ERROR_TEXTS[:not_live]
    end

    def error_is_poor_quality(error_message)
      error_message == ERROR_TEXTS[:poor_quality]
    end

    def selfie_check_performed?
      SELFIE_PERFORMED_STATUSES.include?(selfie_status)
    end

  private

    SELFIE_PERFORMED_STATUSES = %i[success fail].freeze

    ERROR_TEXTS = {
      success: 'Successful. Liveness: Live',
      not_live: 'Liveness: NotLive',
      poor_quality: 'Liveness: PoorQuality',
    }.freeze

    # @param [Object] portrait_match_results trueid portait match info
    def get_portrait_error(portrait_match_results)
      portrait_match_results&.with_indifferent_access&.dig(:FaceErrorMessage)
    end
end
end
