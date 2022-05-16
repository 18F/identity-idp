class PageFooterComponent < BaseComponent
  attr_reader :tag_options

  def initialize(**tag_options)
    @tag_options = tag_options
  end

  def call
    tag.div content, **tag_options, class: css_class
  end

  def css_class
    ['margin-top-4 padding-top-2 border-top border-primary-light', *tag_options[:class]]
  end
end
