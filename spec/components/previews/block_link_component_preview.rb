class BlockLinkComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(BlockLinkComponent.new(url: '', new_tab: false).with_content('Link text'))
  end

  def new_tab
    render(BlockLinkComponent.new(url: '', new_tab: true).with_content('Link text'))
  end
  # @!endgroup

  # @param content text
  # @param url text
  # @param new_tab toggle
  def workbench(content: 'Link text', url: '', new_tab: false)
    render(BlockLinkComponent.new(url: url, new_tab: new_tab).with_content(content))
  end
end
