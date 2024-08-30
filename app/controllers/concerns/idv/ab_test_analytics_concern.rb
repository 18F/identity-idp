# frozen_string_literal: true

module Idv
  module AbTestAnalyticsConcern
    include AcuantConcern
    include OptInHelper

    def ab_test_analytics_buckets
      buckets = {}

      if defined?(idv_session)
        buckets[:skip_hybrid_handoff] = idv_session&.skip_hybrid_handoff
        buckets = buckets.merge(opt_in_analytics_properties)
      end

      buckets
    end
  end
end
