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

    def remaining_attempts
      RateLimiter.new(
        user: document_capture_session.user,
        rate_limit_type: :idv_doc_auth,
      ).remaining_count
    end
  end
end
