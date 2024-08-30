# frozen_string_literal: true

module Redirect
  class PolicyController < RedirectController
    def show
      redirect_to_and_log(policy_url, tracker_method: analytics.method(:policy_redirect))
    end

    private

    def policy_url
      case params[:policy]
      when 'privacy_act_statement'
        MarketingSite.privacy_act_statement_url
      else
        MarketingSite.security_and_privacy_practices_url
      end
    end
  end
end
