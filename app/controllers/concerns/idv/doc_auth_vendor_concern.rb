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

    def doc_auth_vendor_enabled?(vendor)
      return true if IdentityConfig.store.doc_auth_vendor_default == vendor
      return false unless IdentityConfig.store.doc_auth_vendor_switching_enabled

      case vendor
      when Idp::Constants::Vendors::SOCURE
        IdentityConfig.store.doc_auth_vendor_socure_percent > 0
      when Idp::Constants::Vendors::LEXIS_NEXIS
        IdentityConfig.store.doc_auth_vendor_lexis_nexis_percent > 0
      else
        false
      end
    end

    def default_vendor_is_not_mock?
      IdentityConfig.store.doc_auth_vendor_default != Idp::Constants::Vendors::MOCK
    end
  end
end
