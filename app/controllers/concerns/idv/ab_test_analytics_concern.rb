module Idv
  module AbTestAnalyticsConcern
    include AcuantConcern
    include OptInHelper

    def ab_test_analytics_buckets
      buckets = {}
      if defined?(idv_session)
        buckets[:skip_hybrid_handoff] = idv_session&.skip_hybrid_handoff
        buckets[:latest_step_so_far] = idv_session&.latest_step_so_far
        buckets = buckets.merge(opt_in_analytics_properties)
      end

      if defined?(document_capture_session_uuid)
        lniv_args = LexisNexisInstantVerify.new(document_capture_session_uuid).
          workflow_ab_test_analytics_args
        buckets = buckets.merge(lniv_args)
      end

      buckets.merge(acuant_sdk_ab_test_analytics_args)
    end
  end
end
