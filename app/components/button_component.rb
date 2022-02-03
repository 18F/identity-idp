class ButtonComponent < BaseComponent
  attr_reader :type, :factory_args, :factory, :icon, :outline, :tag_options

  DEFAULT_BUTTON_TYPE = :button

  def initialize(*factory_args, factory: :button_tag, icon: nil, outline: false, **tag_options)
    @factory_args = factory_args
    @factory = factory
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

  def content
    if icon
      safe_join([render(IconComponent.new(icon: icon)), super&.strip])
    else
      super
    end
  end
end
