module Users
  class AdditionalMfaRequiredController < ApplicationController
    extend ActiveSupport::Concern

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
  end
end
