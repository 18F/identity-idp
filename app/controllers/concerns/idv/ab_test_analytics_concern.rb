module Idv
  module AbTestAnalyticsConcern
    include AcuantConcern
    include LexisnexisInstantVerify

    def ab_test_analytics_buckets
      buckets = {}
      if defined?(idv_session)
        buckets[:skip_hybrid_handoff] = idv_session&.skip_hybrid_handoff
      end

      buckets.merge(acuant_sdk_ab_test_analytics_args).
        merge(lexisnexis_instant_verify_workflow_ab_test_analytics_args)
    end
  end
end
