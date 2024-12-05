# frozen_string_literal: true

module Idv
  module ByMail
    class SpFollowUpController < ApplicationController
      include Idv::AvailabilityConcern

      before_action :confirm_two_factor_authenticated
      before_action :confirm_needs_sp_follow_up

      def new
        analytics.track_event(:idv_by_mail_sp_follow_up_visited, **analytics_params)
        @presenter = Idv::ByMail::SpFollowUpPresenter.new(current_user:)
      end

      def show
        analytics.track_event(:idv_by_mail_sp_follow_up_submitted, **analytics_params)

        sp_return_url_resolver = SpReturnUrlResolver.new(
          service_provider: current_user.active_profile.initiating_service_provider,
        )
        redirect_url = sp_return_url_resolver.post_idv_follow_up_url ||
                       sp_return_url_resolver.return_to_sp_url
        redirect_to(redirect_url, allow_other_host: true)
      end

      def cancel
        analytics.track_event(:idv_by_mail_sp_follow_up_cancelled, **analytics_params)
        redirect_to account_url
      end

      private

      def analytics_params
        initiating_service_provider = current_user.active_profile.initiating_service_provider
        {
          initiating_service_provider: initiating_service_provider.issuer,
        }
      end

      def confirm_needs_sp_follow_up
        return if current_user.identity_verified? &&
                  current_user.active_profile.initiating_service_provider.present? &&
                  !current_sp.present?
        redirect_to account_url
      end
    end
  end
end
