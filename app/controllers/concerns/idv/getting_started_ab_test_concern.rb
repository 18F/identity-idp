module Idv
  module GettingStartedAbTestConcern
    def getting_started_a_b_test_bucket
      AbTests::IDV_GETTING_STARTED.bucket(sp_session[:request_id] || session.id)
    end

    def maybe_redirect_for_getting_started_ab_test
      return if getting_started_a_b_test_bucket != :getting_started

      redirect_to idv_getting_started_url
    end
  end
end
