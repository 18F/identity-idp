module Users
  class AdditionalMfaRequiredController < ApplicationController
    include SecureHeadersConcern
    extend ActiveSupport::Concern

    before_action :confirm_user_fully_authenticated

    def show
      @content = AdditionalMfaRequiredPresenter.new(current_user: current_user)
      analytics.non_restricted_mfa_required_prompt_visited
    end

    def skip
      user_session[:skip_kantara_req] = true
      if Time.zone.today > enforcement_date
        UpdateUser.new(
          user: current_user,
          attributes: { non_restricted_mfa_required_prompt_skip_date: Time.zone.today },
        ).call
      end
      analytics.non_restricted_mfa_required_prompt_skipped
      # should_count as complete as well
      analytics.user_registration_mfa_setup_complete(
        mfa_method_counts: mfa_context.enabled_two_factor_configuration_counts_hash,
        enabled_mfa_methods_count: mfa_context.enabled_mfa_methods_count,
        pii_like_keypaths: [[:mfa_method_counts, :phone]],
        success: true,
      )
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def enforcement_date
      @enforcement_date ||= IdentityConfig.store.kantara_restriction_enforcement_date
    end

    def mfa_context
      @mfa_context ||= MfaContext.new(current_user)
    end

    def confirm_user_fully_authenticated
      unless user_fully_authenticated?
        return confirm_two_factor_authenticated(sp_session[:request_id])
      end
    end
  end
end
