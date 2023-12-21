require 'ab_test_bucket'

module AbTests
  DOC_AUTH_VENDOR = AbTestBucket.new(
    experiment_name: 'Doc Auth Vendor',
    buckets: {
      alternate_vendor: IdentityConfig.store.doc_auth_vendor_randomize ?
        IdentityConfig.store.doc_auth_vendor_randomize_percent :
        0,
    }.compact,
  )

  ACUANT_SDK = AbTestBucket.new(
    experiment_name: 'Acuant SDK Upgrade',
    buckets: {
      use_alternate_sdk: IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_enabled ?
        IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_percent :
        0,
    },
  )

  LEXISNEXIS_INSTANT_VERIFY_WORKFLOW = AbTestBucket.new(
    experiment_name: 'LexisNexis Instant Verify Workflow',
    buckets: {
      use_alternate_workflow:
        IdentityConfig.store.lexisnexis_instant_verify_workflow_ab_testing_enabled ?
          IdentityConfig.store.lexisnexis_instant_verify_workflow_ab_testing_percent :
          0,
    },
  )
end
