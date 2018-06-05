module ApplicationHelper
  def title(title)
    content_for(:title) { title }
  end

  def card_cls(cls)
    content_for(:card_cls) { cls }
  end

  def step_class(step, active)
    if active > step
      'complete'
    elsif active == step
      'active'
    end
  end

  def tooltip(text)
    content_tag(
      :span, \
      image_tag(asset_url('tooltip.svg'), width: 16, class: 'px1 img-tooltip'), \
      class: 'hint--top hint--no-animate', \
      'aria-label': text, \
      'tabindex': '0'
    )
  end

  def sp_session
    session.fetch(:sp, {})
  end

  def user_signing_up?
    params[:confirmation_token].present? || (current_user && !current_user.two_factor_enabled?)
  end

  def session_with_trust?
    current_user || page_with_trust?
  end

  def page_with_trust?
    current_page?(controller: 'sign_up/passwords', action: 'new') ||
      current_page?(controller: 'users/reset_passwords', action: 'edit')
  end

  def loa3_requested?
    sp_session && sp_session[:loa3]
  end

  def user_verifying_identity?
    return unless current_user
    sp_session && sp_session[:loa3] && current_user.two_factor_enabled?
  end

  def sign_up_or_idv_no_js_link
    if user_signing_up?
      destroy_user_path
    elsif user_verifying_identity?
      idv_session_path
    end
  end

  def cancel_link_text
    if user_signing_up?
      t('links.cancel_account_creation')
    else
      t('links.cancel')
    end
  end
end
