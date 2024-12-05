module Idv
  module ByMail
    class SpFollowUpController < ApplicationController
      include Idv::AvailabilityConcern

      #before_action :confirm_two_factor_authenticated
      #before_action :confirm_needs_sp_follow_up

      def new
        sp_return_url_resolver = SpReturnUrlResolver.new(
          service_provider: current_user.active_profile.initiating_service_provider,
        )
        @post_idv_follow_up_url = sp_return_url_resolver.post_idv_follow_up_url ||
                                  sp_return_url_resolver.return_to_sp_url
      end

      def confirm_needs_sp_follow_up
        return unless current_user.identity_verified? &&
                      current_user.active_profile.initiating_service_provider.present? &&
                      !current_sp.present?
        redirect_to account_url
      end
    end
  end
end
