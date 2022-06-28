class BlockLinkComponent < BaseComponent
  attr_reader :url, :action, :new_tab, :tag_options

  def initialize(url:, action: tag.method(:a), new_tab: false, **tag_options)
    @action = action
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

  def wrapper(&block)
    wrapper = action.call(**tag_options, href: url, class: css_class, target: target, &block)
    if wrapper.respond_to?(:render_in)
      render wrapper, &block
    else
      wrapper
    end
  end
end
