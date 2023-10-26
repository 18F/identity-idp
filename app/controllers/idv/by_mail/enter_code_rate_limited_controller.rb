module Idv
  module ByMail
    class EnterCodeRateLimitedController < ApplicationController
      include IdvSession
      include FraudReviewConcern

      before_action :confirm_two_factor_authenticated
      before_action :confirm_verification_needed

      def index
        irs_attempts_api_tracker.idv_gpo_verification_rate_limited
        analytics.rate_limit_reached(
          limiter_type: :verify_gpo_key,
        )

        @expires_at = rate_limiter.expires_at
      end
    end
  end
end
