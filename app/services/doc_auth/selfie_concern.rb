module DocAuth
  module SelfieConcern
    extend ActiveSupport::Concern
    def selfie_live?
      portait_error = get_portrait_error(portrait_match_results)
      return true if portait_error.nil? || portait_error.empty?
      return error_is_not_live(portait_error)
    end

    def selfie_quality_good?
      portait_error = get_portrait_error(portrait_match_results)
      return true if portait_error.nil? || portait_error.empty?
      return error_is_poor_quality(portait_error)
    end

    def error_is_success(error_message)
      return error_message == ERROR_TEXTS['success']
    end

    def error_is_not_live(error_message)
      return error_message == ERROR_TEXTS['not_live']
    end

    def error_is_poor_quality(error_message)
      return error_message == ERROR_TEXTS['poor_quality']
    end

  private

    ERROR_TEXTS = {
      success: 'Successful. Liveness: Live',
      not_live: 'Liveness: NotLive',
      poor_quality: 'Liveness: PoorQuality',
    }

    # @param [Object] portrait_match_results trueid portait match info
    def get_portrait_error(portrait_match_results)
      portrait_match_results&.with_indifferent_access&.dig(:FaceErrorMessage)
    end
end
end
