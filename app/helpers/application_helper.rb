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

  def decorated_session
    @_decorated_session ||= begin
      if @sp_name.present?
        ServiceProviderSessionDecorator.new(
          sp_name: @sp_name, sp_logo: @sp_logo
        )
      else
        SessionDecorator.new
      end
    end
  end

  def sp_session
    session[:sp]
  end

  def sign_up_init?
    session[:sign_up_init]
  end

  def user_signing_up?
    !current_user || !current_user.two_factor_enabled?
  end

  def loa3_requested?
    sp_session && sp_session[:loa3]
  end

  def user_verifying_identity?
    return unless current_user
    sp_session && sp_session[:loa3] && current_user.two_factor_enabled?
  end

  def sign_up_or_idv_no_js_link
    if sign_up_init?
      root_path
    elsif user_signing_up?
      destroy_user_path
    elsif user_verifying_identity?
      verify_session_path
    end
  end

  def cancel_link_text
    if user_signing_up?
      t('links.cancel_account_creation')
    elsif user_verifying_identity?
      t('links.cancel_idv')
    else
      t('links.cancel')
    end
  end
end
