module ApplicationHelper
  def title(title)
    content_for(:title) { title }
  end

  def background_cls(cls)
    content_for(:background_cls) { cls }
  end

  def sp_session
    session.fetch(:sp, {})
  end

  def user_signing_up?
    params[:confirmation_token].present? || (
      current_user && !MfaPolicy.new(current_user).two_factor_enabled?
    )
  end

  def session_with_trust?
    current_user || page_with_trust?
  end

  def page_with_trust?
    return false if current_page?(controller: 'users/sessions', action: 'new')
    return true
  end

  def ial2_requested?
    sp_session && sp_session[:ial2]
  end

  def liveness_checking_enabled?
    return false if !FeatureManagement.liveness_checking_enabled?
    return sp_session[:ial2_strict] if sp_session.key?(:ial2_strict)
    !!current_user&.decorate&.password_reset_profile&.includes_liveness_check?
  end

  def cancel_link_text
    if user_signing_up?
      t('links.cancel_account_creation')
    else
      t('links.cancel')
    end
  end

  def desktop_device?
    DeviceDetector.new(request.user_agent)&.device_type == 'desktop'
  end
end
