module Aal3Concern
  extend ActiveSupport::Concern

  def confirm_user_has_aal3_mfa_if_requested
    return unless aal3_policy.aal3_required?
    return if mfa_policy.aal3_mfa_enabled?
    redirect_to two_factor_options_url
  end

  def aal3_redirect_url(user)
    if TwoFactorAuthentication::PivCacPolicy.new(user).enabled? && !mobile?
      login_two_factor_piv_cac_url
    elsif TwoFactorAuthentication::WebauthnPolicy.new(user).enabled?
      login_two_factor_webauthn_url
    else
      aal3_required_url
    end
  end
end
