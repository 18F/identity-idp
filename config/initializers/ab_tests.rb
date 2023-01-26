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

  in_person_cta_variant_testing_buckets = Hash.new
  if IdentityConfig.store.in_person_cta_variant_testing_enabled
    IdentityConfig.store.in_person_cta_variant_testing_percents.each do |variant, rate|
      bucket_name = 'in_person_variant_' + variant.to_s.downcase
      in_person_cta_variant_testing_buckets[bucket_name.to_sym] = rate
    end
  else
    in_person_cta_variant_testing_buckets['in_person_variant_a'] = 100
  end
  IN_PERSON_CTA = AbTestBucket.new(
    experiment_name: 'In-Person Proofing CTA',
    buckets: in_person_cta_variant_testing_buckets,
    default_bucket: 'in_person_variant_a',
  )
end
