# frozen_string_literal: true

class TagComponent < BaseComponent
  attr_reader :big, :informative, :tag_options
  alias_method :big?, :big
  alias_method :informative?, :informative

  def initialize(big: false, informative: false, **tag_options)
    @big = big
    @informative = informative
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-tag', *tag_options[:class]]
    classes << 'usa-tag--big' if big?
    classes << 'usa-tag--informative' if informative?
    classes
  end

  def call
    content_tag(:span, content, **tag_options, class: css_class)
  end

  private :big, :informative
end
