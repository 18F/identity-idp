class BlockLinkComponent < BaseComponent
  attr_reader :url, :action, :new_tab, :tag_options, :render_as_link

  alias_method :new_tab?, :new_tab

  def initialize(url: '#', render_as_link: true, new_tab: false, **tag_options)
    @url = url
    @render_as_link = render_as_link
    @new_tab = new_tab
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-link', 'block-link', *tag_options[:class]]
    classes << 'usa-link--external' if new_tab?
    classes
  end

  def target
    '_blank' if new_tab?
  end

  def wrapper(&block)
    if render_as_link
      action = tag.method(:a)
      action.call(**tag_options, href: url, class: css_class, target:, &block)
    else
      content_tag(:div, capture(&block), class: "usa-link block-link")
    end
  end
end
