# frozen_string_literal: true

module Idv
  module DocAuthVendorConcern
    include AbTestingConcern

    # @returns[String] String identifying the vendor to use for doc auth.
    def doc_auth_vendor
      if resolved_authn_context_result.facial_match?
        return nil if lexis_nexis_not_enabled?
        bucket = default_vendor_is_not_mock? ? :lexis_nexis : :mock
      else
        bucket = ab_test_bucket(:DOC_AUTH_VENDOR)
      end
      DocAuthRouter.doc_auth_vendor_for_bucket(bucket)
    end

    def lexis_nexis_not_enabled?
      (IdentityConfig.store.doc_auth_vendor_default == Idp::Constants::Vendors::SOCURE ||
        IdentityConfig.store.doc_auth_vendor_default.nil?) &&
        IdentityConfig.store.doc_auth_vendor_lexis_nexis_percent == 0
    end

    def default_vendor_is_not_mock?
      IdentityConfig.store.doc_auth_vendor_default != Idp::Constants::Vendors::MOCK
    end
  end
end
