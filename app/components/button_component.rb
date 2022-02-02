class ButtonComponent < BaseComponent
  attr_reader :type, :factory_args, :factory, :outline, :tag_options

  DEFAULT_BUTTON_TYPE = :button

  def initialize(*factory_args, factory: :button_tag, outline: false, **tag_options)
    @factory_args = factory_args
    @factory = factory
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
end
