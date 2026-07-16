# frozen_string_literal: true

module Idv
  module DocAuthVendorConcern
    include AbTestingConcern

    def update_doc_auth_vendor(user: current_user)
      if document_capture_session.doc_auth_vendor.blank?
        document_capture_session.update!(doc_auth_vendor: bucketed_doc_auth_vendor(user))
      end
    end

    private

    # @returns[String] String identifying the vendor to use for doc auth.
    def bucketed_doc_auth_vendor(user)
      @bucketed_doc_auth_vendor ||= begin
        bucket = nil
        if resolved_authn_context_result.facial_match?
          if document_capture_session.passport_requested?
            bucket = ab_test_bucket(:DOC_AUTH_PASSPORT_SELFIE_VENDOR, user:)
          else
            bucket = ab_test_bucket(:DOC_AUTH_SELFIE_VENDOR, user:)
          end
        elsif document_capture_session.passport_requested?
          bucket = ab_test_bucket(:DOC_AUTH_PASSPORT_VENDOR, user:)
        else
          bucket = ab_test_bucket(:DOC_AUTH_VENDOR, user:)
        end

        DocAuthRouter.doc_auth_vendor_for_bucket(
          bucket,
          selfie: resolved_authn_context_result.facial_match?,
          passport_requested: document_capture_session.passport_requested?,
        )
      end
    end
  end
end
