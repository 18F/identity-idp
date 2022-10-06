require 'ab_test_bucket'

module AbTests
  NATIVE_CAMERA = AbTestBucket.new(
    experiment_name: 'Native Camera Only',
    buckets: {
      native_camera_only: IdentityConfig.store.idv_native_camera_a_b_testing_enabled ?
        IdentityConfig.store.idv_native_camera_a_b_testing_percent :
        nil,
    }.compact,
  )

  DOC_AUTH_VENDOR = AbTestBucket.new(
    experiment_name: 'Doc Auth Vendor',
    buckets: {
      alternate_vendor: IdentityConfig.store.doc_auth_vendor_randomize ?
        IdentityConfig.store.doc_auth_vendor_randomize_percent :
        nil,
    }.compact,
  )

  KEY_PAIR_GENERATION = AbTestBucket.new(
    experiment_name: 'Key Pair Generation',
    buckets: {
      key_pair_group: IdentityConfig.store.key_pair_generation_percent,
    },
  )
end
