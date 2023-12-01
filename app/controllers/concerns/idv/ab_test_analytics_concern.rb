module Idv
  module AbTestAnalyticsConcern
    include AcuantConcern
    include Idv::PhoneQuestionAbTestConcern

    def ab_test_analytics_buckets
      buckets = {}
      if defined?(idv_session)
        buckets[:skip_hybrid_handoff] = idv_session&.skip_hybrid_handoff
        buckets[:phone_with_camera] = idv_session&.phone_with_camera
      end

      buckets.merge(acuant_sdk_ab_test_analytics_args).
        merge(phone_question_ab_test_analytics_bucket)
    end
  end
end
