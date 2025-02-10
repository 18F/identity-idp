# frozen_string_literal: true

class BlockLinkComponent < BaseComponent
  attr_reader :url, :action, :new_tab, :tag_options, :component

  alias_method :new_tab?, :new_tab

  def initialize(url: '#', component: nil, new_tab: false, **tag_options)
    @url = url
    @component = component
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
    if component
      render component.new(href: url, class: css_class), &block
    else
      action = tag.method(:a)
      action.call(**tag_options, href: url, class: css_class, target:, &block)
    end
  end
end
