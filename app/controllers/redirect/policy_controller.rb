# frozen_string_literal: true

module Redirect
  class PolicyController < RedirectController
    def show
      redirect_to_and_log(
        MarketingSite.security_and_privacy_practices_url,
        tracker_method: analytics.method(:policy_redirect),
      )
    end
  end
  end
