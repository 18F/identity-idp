class ButtonComponent < BaseComponent
  attr_reader :action, :icon, :big, :wide, :outline, :tag_options

  def initialize(
    action: ->(**tag_options, &block) { button_tag(**tag_options, &block) },
    icon: nil,
    big: false,
    wide: false,
    outline: false,
    **tag_options
  )
    @action = action
    @icon = icon
    @big = big
    @wide = wide
    @outline = outline
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--big' if big
    classes << 'usa-button--wide' if wide
    classes << 'usa-button--outline' if outline
    classes
  end

  def icon_content
    render IconComponent.new(icon: icon) if icon
  end
end
