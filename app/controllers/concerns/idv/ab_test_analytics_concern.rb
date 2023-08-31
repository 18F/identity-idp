module Idv
  module AbTestAnalyticsConcern
    include AcuantConcern
    include Idv::GettingStartedAbTestConcern

    def ab_test_analytics_buckets
      acuant_sdk_ab_test_analytics_args.
        merge(getting_started_ab_test_analytics_bucket)
    end
  end
end
