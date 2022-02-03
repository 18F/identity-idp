class ButtonComponent < BaseComponent
  attr_reader :action, :icon, :outline, :tag_options

  def initialize(
    action: ->(**tag_options, &block) { button_tag(**tag_options, &block) },
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

  def icon_content
    render IconComponent.new(icon: icon) if icon
  end
end
