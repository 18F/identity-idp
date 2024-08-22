# frozen_string_literal: true

module Idv
  module DocAuthVendorConcern
    include AbTestingConcern

    # @returns[String] String identifying the vendor to use for doc auth.
    def doc_auth_vendor
      bucket = ab_test_bucket(:DOC_AUTH_VENDOR)
      DocAuthRouter.doc_auth_vendor_for_bucket(bucket)
    end
  end
end
