# frozen_string_literal: true

module Idv
  module AcuantConcern
    include AbTestingConcern

    def acuant_sdk_upgrade_a_b_testing_variables
      bucket = ab_test_bucket(:ACUANT_SDK)
      testing_enabled = IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_enabled &&
                        bucket.present?
      use_alternate_sdk = (bucket == :use_alternate_sdk)

      if use_alternate_sdk
        acuant_version = IdentityConfig.store.idv_acuant_sdk_version_alternate
      else
        acuant_version = IdentityConfig.store.idv_acuant_sdk_version_default
      end

      {
        acuant_sdk_upgrade_a_b_testing_enabled: testing_enabled,
        use_alternate_sdk: use_alternate_sdk,
        acuant_version: acuant_version,
      }
    end

    def override_csp_to_allow_acuant
      policy = current_content_security_policy
      request.content_security_policy_nonce_directives =
        request.content_security_policy_nonce_directives.without('style-src')
      policy.connect_src(*policy.connect_src, 'us.acas.acuant.net')
      policy.script_src(*policy.script_src, :unsafe_eval)
      policy.style_src(*policy.style_src, :unsafe_inline)
      policy.img_src(*policy.img_src, 'blob:')
      request.content_security_policy = policy
    end
  end
end
