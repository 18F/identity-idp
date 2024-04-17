# frozen_string_literal: true

module DocAuth
  module SelfieConcern
    extend ActiveSupport::Concern
    def selfie_live?
      portrait_error = get_portrait_error(portrait_match_results)
      return true if portrait_error.nil? || portrait_error.blank?
      !error_is_not_live(portrait_error)
    end

    def selfie_quality_good?
      selfie_live? # can remove this method?
    end

    def error_is_not_live(error_message)
      NOT_LIVE_TEXTS.include?(error_message)
    end

    def selfie_check_performed?
      SELFIE_PERFORMED_STATUSES.include?(selfie_status)
    end

    private

    SELFIE_PERFORMED_STATUSES = %i[success fail].freeze

    NOT_LIVE_TEXTS = [
      'Liveness: NotLive',
      'Liveness: PoorQuality',
      'Liveness: Error',
    ].freeze

    # @param [Object] portrait_match_results trueid portrait match info
    def get_portrait_error(portrait_match_results)
      portrait_match_results&.with_indifferent_access&.dig(:FaceErrorMessage)
    end
  end
end
