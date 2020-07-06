module Aal3Concern
  extend ActiveSupport::Concern

  def confirm_user_has_aal3_mfa_if_requested
    return unless aal3_policy.aal3_required?
    return if mfa_policy.aal3_mfa_enabled?
    redirect_to two_factor_options_url
  end
end
