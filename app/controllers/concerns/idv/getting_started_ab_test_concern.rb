module Idv
  module GettingStartedAbTestConcern
    def getting_started_ab_test_bucket
      AbTests::IDV_GETTING_STARTED.bucket(getting_started_user.uuid)
    end

    def getting_started_user
      if defined?(document_capture_user) # hybrid flow
        document_capture_user
      else
        current_user
      end
    end

    def maybe_redirect_for_getting_started_ab_test
      return if getting_started_ab_test_bucket != :getting_started

      redirect_to idv_getting_started_url
    end

    def getting_started_ab_test_analytics_bucket
      {
        getting_started_ab_test_bucket:,
      }
    end
  end
end
