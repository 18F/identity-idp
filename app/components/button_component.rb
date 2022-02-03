class ButtonComponent < BaseComponent
  attr_reader :action, :icon, :outline, :tag_options

  DEFAULT_BUTTON_TYPE = :button

  def initialize(
    action: ->(content, **tag_options) { button_tag(content, **tag_options) },
    icon: nil,
    outline: false,
    **tag_options
  )
    @action = action
    @icon = icon
    @outline = outline
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--outline' if outline
    classes
  end

  def tag_type
    tag_options.fetch(:type, DEFAULT_BUTTON_TYPE)
  end

  def icon_content
    render IconComponent.new(icon: icon) if icon
  end
end
