module Users
  class AdditionalMfaRequiredController < ApplicationController
    include SecureHeadersConcern
    extend ActiveSupport::Concern

    before_action :confirm_user_fully_uathenticated

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
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def enforcement_date
      @enforcement_date ||= IdentityConfig.store.kantara_restriction_enforcement_date
    end

    def confirm_user_fully_uathenticated
      unless user_fully_authenticated?
        return confirm_two_factor_authenticated(sp_session[:request_id])
      end
    end
  end
end
