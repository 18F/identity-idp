class LoginButtonComponent < BaseComponent
  attr_reader :action, :big, :color, :width, :height, :logo_path, :tag_options

  alias_method :big?, :big

  DEFAULT_HEIGHT = 16
  DEFAULT_WIDTH = 121
  BIG_HEIGHT = 20
  BIG_WIDTH = 152

  def initialize(
    action: ->(**tag_options, &block) { button_tag(**tag_options, &block) },
    big: false,
    color: "light blue",
    **tag_options
  )
    @action = action
    @big = big
    @color = color
    @tag_options = tag_options
  end

  def logo_path
    return "logo-white.svg" if color == "dark blue"
    "logo.svg"
  end

  def width
    return BIG_WIDTH if big?
    DEFAULT_WIDTH
  end

  def height
    return BIG_HEIGHT if big?
    DEFAULT_HEIGHT
  end

  def css_class
    classes = ['usa-button', *tag_options[:class]]
    classes << 'usa-button--big' if big
    classes << 'bg-white text-primary-darker border border-base hover:border hover:bg-white hover:text-primary-darker hover:border-base' if color == "white"
    classes << 'bg-primary-lighter text-primary-darker hover:bg-primary-lighter hover:text-primary-darker' if color == "light blue"
    classes << 'bg-primary-darker text-white hover:bg-primary-darker hover:text-white' if color == "dark blue"
    classes
  end

  def content
    original_content = super
    if original_content.present?
      # Content templates may include leading whitespace, which interferes with the layout when an
      # icon is present. This can be solved in CSS using Flexbox, but doing so for all buttons may
      # have unintended consequences.
      trimmed_content = original_content.lstrip
      trimmed_content = sanitize(trimmed_content) if original_content.html_safe?
      trimmed_content
    else
      original_content
    end
  end
end
