class BlockLinkComponent < BaseComponent
  attr_reader :url, :new_tab, :tag_options

  def initialize(url:, new_tab: false, **tag_options)
    @url = url
    @new_tab = new_tab
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-link', 'block-link', *tag_options[:class]]
    classes << 'usa-link--external' if new_tab
    classes
  end

  def target
    '_blank' if new_tab
  end
end
