class LoginButtonComponent < BaseComponent
  attr_reader :action, :big, :color, :outline, :tag_options

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
