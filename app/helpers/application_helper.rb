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

  def cancel_link_text
    if user_signing_up?
      t('links.cancel_account_creation')
    else
      t('links.cancel')
    end
  end

  def desktop_device?
    !BrowserCache.parse(request.user_agent).mobile?
  end
end
