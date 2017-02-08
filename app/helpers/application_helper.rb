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
    if @sp_name.present?
      @_decorated_session ||= ServiceProviderSessionDecorator.new(
        sp_name: @sp_name, sp_logo: @sp_logo
      )
    else
      @_decorated_session ||= SessionDecorator.new
    end
  end

  def service_provider
    session[:sp]
  end

  def loa3_context?
    provider = service_provider
    provider && provider[:loa3] && current_user.recovery_code.present?
  end
end
