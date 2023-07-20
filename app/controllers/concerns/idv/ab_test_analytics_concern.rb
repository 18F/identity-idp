module Idv
  module AbTestAnalyticsConcern
    include AcuantConcern

    def ab_test_analytics_args
      acuant_sdk_ab_test_analytics_args
    end
  end
end
