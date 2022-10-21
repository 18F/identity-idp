class PageFooterComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(PageFooterComponent.new.with_content('Example Content'))
  end
  # @!endgroup

  # @param content text
  def workbench(content: 'Example Content')
    render(PageFooterComponent.new.with_content(content))
  end
end
