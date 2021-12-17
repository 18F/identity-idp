class ButtonComponent < BaseComponent
  attr_reader :type, :outline, :tag_options

  DEFAULT_BUTTON_TYPE = :button

  def initialize(outline: false, **tag_options)
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
