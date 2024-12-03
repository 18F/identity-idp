# frozen_string_literal: true

module Idv
  module SocureErrorsConcern
    def errors
      @presenter = socure_errors_presenter(handle_stored_result)
    end

    def goto_in_person
      InPersonEnrollment.find_or_initialize_by(
        user: document_capture_session.user,
        status: :establishing,
        sponsor_id: IdentityConfig.store.usps_ipp_sponsor_id,
      ).save!

      redirect_to idv_in_person_url
    end

    private

    def remaining_attempts
      RateLimiter.new(
        user: document_capture_session.user,
        rate_limit_type: :idv_doc_auth,
      ).remaining_count
    end

    def error_code_for(result)
      if result.errors[:socure]
        result.errors.dig(:socure, :reason_codes).first
      elsif result.errors[:network]
        :network
      else
        # No error information available (shouldn't happen). Default
        # to :network if it does.
        :network
      end
    end
  end
end
