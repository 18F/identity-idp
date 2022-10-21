class PageFooterComponentPreview < BaseComponentPreview
  # @!group Kitchen Sink
  def default
    render(PageFooterComponent.new.with_content('Example Content'))
  end
  # @!endgroup

  # @param content text
  def playground(content: 'Example Content')
    render(PageFooterComponent.new.with_content(content))
  end
end
