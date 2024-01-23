module DocAuth
  module SelfieConcern
    extend ActiveSupport::Concern
    def selfie_live?
      portrait_match_results ||= {}
      portait_error = get_portrait_error(portrait_match_results)
      return portait_error != 'Liveness: NotLive'
    end

    def selfie_quality_good?
      portrait_match_results ||= {}
      portait_error = get_portrait_error(portrait_match_results)
      return portait_error != 'Liveness: PoorQuality'
    end

  private

    # @param [Object] portrait_match_results trueid portait match info
    def get_portrait_error(portrait_match_results)
      portrait_match_results&.with_indifferent_access&.dig(:FaceErrorMessage)
    end
end
end
