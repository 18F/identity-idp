class AccordionComponentPreview < BaseComponentPreview
  # @!group Kitchen Sink
  def default
    render(AccordionComponent.new) do |c|
      c.header { 'Header' }
      'Content'
    end
  end

  def unbordered
    render(AccordionComponent.new(bordered: false)) do |c|
      c.header { 'Header' }
      'Content'
    end
  end
  # @!endgroup

  # @param header text
  # @param content text
  # @param bordered toggle
  def playground(header: 'Header', content: 'Content', bordered: true)
    render(AccordionComponent.new(bordered: bordered)) do |c|
      c.header { header }
      content
    end
  end
end
