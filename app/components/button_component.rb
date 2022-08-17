class ButtonComponent < BaseComponent
  attr_reader :action, :icon, :big, :wide, :full_width, :outline, :unstyled, :danger, :tag_options

  def initialize(
    action: ->(**tag_options, &block) { button_tag(**tag_options, &block) },
    icon: nil,
    big: false,
    wide: false,
    full_width: false,
    outline: false,
    unstyled: false,
    danger: false,
    **tag_options
  )
    @action = action
    @icon = icon
    @big = big
    @wide = wide
    @full_width = full_width
    @outline = outline
    @unstyled = unstyled
    @danger = danger
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--big' if big
    classes << 'usa-button--wide' if wide
    classes << 'usa-button--full-width' if full_width
    classes << 'usa-button--outline' if outline
    classes << 'usa-button--unstyled' if unstyled
    classes << 'usa-button--danger' if danger
    classes
  end

  def icon_content
    render IconComponent.new(icon: icon) if icon
  end
end
