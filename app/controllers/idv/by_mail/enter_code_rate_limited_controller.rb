# frozen_string_literal: true

module Idv
  module ByMail
    class EnterCodeRateLimitedController < ApplicationController
      include Idv::AvailabilityConcern
      include IdvSessionConcern
      include FraudReviewConcern

      before_action :confirm_two_factor_authenticated
      before_action :confirm_verification_needed

      def index
        analytics.rate_limit_reached(
          limiter_type: :verify_gpo_key,
        )

        @expires_at = rate_limiter.expires_at
      end

      private

      def rate_limiter
        @rate_limiter ||= RateLimiter.new(
          user: current_user,
          rate_limit_type: :verify_gpo_key,
        )
      end

      def confirm_verification_needed
        return if current_user.gpo_verification_pending_profile?
        redirect_to account_url
      end
    end
  end
end
