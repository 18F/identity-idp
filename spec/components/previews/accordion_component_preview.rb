class AccordionComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(AccordionComponent.new) do |c|
      c.with_header { 'Header' }
      'Content'
    end
  end

  def unbordered
    render(AccordionComponent.new(bordered: false)) do |c|
      c.with_header { 'Header' }
      'Content'
    end
  end
  # @!endgroup

  # @param header text
  # @param content text
  # @param bordered toggle
  def workbench(header: 'Header', content: 'Content', bordered: true)
    render(AccordionComponent.new(bordered:)) do |c|
      c.with_header { header }
      content
    end
  end
end
