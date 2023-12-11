module Idv
  class LexisnexisInstantVerify
    attr_reader :document_capture_session_uuid

    def initialize(document_capture_session_uuid = nil)
      @document_capture_session_uuid = document_capture_session_uuid
    end

    def workflow_ab_test_analytics_args
      return {} if document_capture_session_uuid.blank?

      {
        lexisnexis_instant_verify_workflow_ab_test_bucket:
          AbTests::LEXISNEXIS_INSTANT_VERIFY_WORKFLOW.bucket(document_capture_session_uuid),
      }
    end

    def workflow_ab_testing_variables
      bucket = AbTests::LEXISNEXIS_INSTANT_VERIFY_WORKFLOW.bucket(document_capture_session_uuid)
      testing_enabled = IdentityConfig.store.lexisnexis_instant_verify_workflow_ab_testing_enabled
      use_alternate_workflow = (bucket == :use_alternate_workflow)

      if use_alternate_workflow
        instant_verify_workflow = IdentityConfig.store.lexisnexis_instant_verify_workflow_alternate
      else
        instant_verify_workflow = IdentityConfig.store.lexisnexis_instant_verify_workflow
      end

      {
        ab_testing_enabled: testing_enabled,
        use_alternate_workflow: use_alternate_workflow,
        instant_verify_workflow: instant_verify_workflow,
      }
    end
  end
end
