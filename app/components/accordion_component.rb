# frozen_string_literal: true

class AccordionComponent < BaseComponent
  renders_one :header

  attr_reader :bordered, :tag_options

  def initialize(bordered: true, **tag_options)
    @bordered = bordered
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-accordion', *tag_options[:class]]
    classes << 'usa-accordion--bordered' if bordered
    classes
  end
end
