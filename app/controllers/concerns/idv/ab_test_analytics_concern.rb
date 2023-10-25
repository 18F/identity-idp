# frozen_string_literal: true

module Idv
  module AbTestAnalyticsConcern
    include AcuantConcern
    include Idv::GettingStartedAbTestConcern
    include Idv::PhoneQuestionAbTestConcern

    def ab_test_analytics_buckets
      buckets = {}
      if defined?(idv_session)
        buckets[:skip_hybrid_handoff] = idv_session&.skip_hybrid_handoff
      end

      buckets.merge(acuant_sdk_ab_test_analytics_args).
        merge(getting_started_ab_test_analytics_bucket).
        merge(phone_question_ab_test_analytics_bucket)
    end
  end
end
