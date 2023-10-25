# frozen_string_literal: true

module Idv
  module AcuantConcern
    def acuant_sdk_ab_test_analytics_args
      return {} if document_capture_session_uuid.blank?

      {
        acuant_sdk_upgrade_ab_test_bucket:
          AbTests::ACUANT_SDK.bucket(document_capture_session_uuid),
      }
    end

    def acuant_sdk_upgrade_a_b_testing_variables
      bucket = AbTests::ACUANT_SDK.bucket(document_capture_session_uuid)
      testing_enabled = IdentityConfig.store.idv_acuant_sdk_upgrade_a_b_testing_enabled
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
      policy.connect_src(*policy.connect_src, 'us.acas.acuant.net')
      policy.script_src(*policy.script_src, :unsafe_eval)
      policy.style_src(*policy.style_src, :unsafe_inline)
      policy.img_src(*policy.img_src, 'blob:')
      request.content_security_policy = policy
    end
  end
end
