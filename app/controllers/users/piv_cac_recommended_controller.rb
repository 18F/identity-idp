module Users
  class PivCacRecommendedController < ApplicationController
    include TwoFactorAuthenticatableMethods
    include MfaSetupConcern
    include SecureHeadersConcern
    include ReauthenticationRequiredConcern

    before_action :authenticate_user!
    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :apply_secure_headers_override
    before_action :user_email_is_gov_or_mil?

    def show
      @recommended_presenter = PivCacRecommendedPresenter.new(current_user)
      analytics.piv_cac_recommended_visited
    end

    def confirm
      UpdateUser.new(
        user: current_user,
        attributes: { piv_cac_recommended_visited_at: Time.zone.now },
      ).call
      analytics.piv_cac_recommended(action: :accepted)
      set_piv_cac_as_option_and_redirect
    end

    def skip
      UpdateUser.new(
        user: current_user,
        attributes: { piv_cac_recommended_visited_at: Time.zone.now },
      ).call
      analytics.piv_cac_recommended(action: :skipped)
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def user_email_is_gov_or_mil?
      redirect_to after_sign_in_path_for(current_user) unless current_user.has_gov_or_mil_email?
    end
  end
end
