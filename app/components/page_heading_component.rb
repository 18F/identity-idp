# frozen_string_literal: true

class PageHeadingComponent < BaseComponent
  attr_reader :tag_options

  def initialize(**tag_options)
    @tag_options = tag_options
  end

  def call
    tag.h1 content, **tag_options, class: ['page-heading', *tag_options[:class]]
  end
end
