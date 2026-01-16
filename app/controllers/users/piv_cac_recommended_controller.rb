# frozen_string_literal: true

module Users
  class PivCacRecommendedController < ApplicationController
    include TwoFactorAuthenticatableMethods
    include MfaSetupConcern
    include ThreatMetrixHelper
    include SecureHeadersConcern

    before_action :confirm_user_authenticated_for_2fa_setup
    before_action :apply_secure_headers_override
    before_action :redirect_unless_user_email_is_fed_or_mil

    def show
      @recommended_presenter = PivCacRecommendedPresenter.new(current_user)
      analytics.piv_cac_recommended_visited
      render :show, locals: threatmetrix_variables
    end

    def confirm
      current_user.update!(piv_cac_recommended_dismissed_at: Time.zone.now)
      analytics.piv_cac_recommended(action: :accepted)
      set_mfa_selections(['piv_cac'])
      redirect_to first_mfa_selection_path
    end

    def skip
      current_user.update!(piv_cac_recommended_dismissed_at: Time.zone.now)
      analytics.piv_cac_recommended(action: :skipped)
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def redirect_unless_user_email_is_fed_or_mil
      redirect_to after_sign_in_path_for(current_user) unless current_user.has_fed_or_mil_email?
    end
  end
end
