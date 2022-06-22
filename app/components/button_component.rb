class ButtonComponent < BaseComponent
  attr_reader :action, :href, :method, :unstyled, :icon, :big, :wide, :outline, :tag_options

  def initialize(
    action: ->(**tag_options, &block) do
      content_tag(tag_name, **tag_options.except(:method), &block)
    end,
    href: nil,
    method: nil,
    unstyled: false,
    icon: nil,
    big: false,
    wide: false,
    outline: false,
    **tag_options
  )
    @action = action
    @href = href
    @method = method
    @unstyled = unstyled
    @icon = icon
    @big = big
    @wide = wide
    @outline = outline
    @tag_options = tag_options
  end

  def scripts
    super if form_link?
  end

  def css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--big' if big
    classes << 'usa-button--wide' if wide
    classes << 'usa-button--outline' if outline
    classes << 'usa-button--unstyled' if unstyled
    classes
  end

  def icon_content
    render IconComponent.new(icon: icon) if icon
  end

  def tag_name
    if href
      :a
    else
      :button
    end
  end

  def form_id
    "button-form-#{unique_id}" if form_link?
  end

  def form_link?
    href.present? && method.present?
  end
end
