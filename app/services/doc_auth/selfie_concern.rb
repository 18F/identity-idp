# frozen_string_literal: true

# update namespace to LN/TrueID specific
module DocAuth
  module SelfieConcern
    extend ActiveSupport::Concern
    def selfie_live?
      portrait_error = get_portrait_error(portrait_match_results)
      return true if portrait_error.blank?
      !error_is_not_live(portrait_error)
    end

    def selfie_quality_good?
      portrait_error = get_portrait_error(portrait_match_results)
      return true if portrait_error.blank?
      !error_is_poor_quality(portrait_error)
    end

    def error_is_not_live(error_message)
      error_message == ERROR_TEXTS[:not_live]
    end

    def error_is_poor_quality(error_message)
      error_message == ERROR_TEXTS[:poor_quality]
    end

    def selfie_check_performed?
      SELFIE_PERFORMED_STATUSES.include?(selfie_status)
    end

    def selfie_check_passed?
      selfie_status == :success
    end

    private

    SELFIE_PERFORMED_STATUSES = %i[success fail].freeze

    ERROR_TEXTS = {
      success: 'Successful. Liveness: Live',
      not_live: 'Liveness: NotLive',
      poor_quality: 'Liveness: PoorQuality',
    }.freeze

    # @param [Object] portrait_match_results trueid portrait match info
    def get_portrait_error(portrait_match_results)
      portrait_match_results&.with_indifferent_access&.dig(:FaceErrorMessage)
    end
  end
end
