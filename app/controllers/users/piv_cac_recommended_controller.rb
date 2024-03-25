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

    helper_method :in_multi_mfa_selection_flow?

    def show
      @email_type = email_type
      @skip_text = skip_text
      analytics.piv_cac_recommended_page_visited
    end

    def confirm
      UpdateUser.new(user: current_user, attributes: { piv_cac_recommended_dismissed: true }).call
      user_session[:mfa_selections] = ['piv_cac']
      analytics.piv_cac_recommended_accepted
      redirect_to confirmation_path(user_session[:mfa_selections].first)
    end

    def skip
      UpdateUser.new(user: current_user, attributes: { piv_cac_recommended_dismissed: true }).call
      analytics.piv_cac_recommended_skipped
      redirect_to after_sign_in_path_for(current_user)
    end

    private

    def user_email_is_gov_or_mil?
      binding.pry
      redirect_to after_sign_in_path_for(current_user) unless current_user.has_gov_or_mil_email?
    end

    def email_type
      address = current_user.confirmed_email_addresses.select { |address| address.gov_or_mil? }
      case address.first.email.end_with?('.gov')
      when true
        '.gov'
      else
        '.mil'
      end
    end

    def skip_text
      if MfaPolicy.new(current_user).two_factor_enabled?
        t('mfa.skip')
      else
        t('two_factor_authentication.piv_cac_upsell.choose_other_method')
      end
    end
  end
end
