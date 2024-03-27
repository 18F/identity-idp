class AccordionComponent < BaseComponent
  renders_one :header

  attr_reader :bordered, :tag_options

  def initialize(bordered: true, expanded: false, **tag_options)
    @bordered = bordered
    @expanded = expanded
    @tag_options = tag_options
  end

  def css_class
    classes = ['usa-accordion', *tag_options[:class]]
    classes << 'usa-accordion--bordered' if bordered
    classes
  end

  def expanded?
    @expanded
  end
end
