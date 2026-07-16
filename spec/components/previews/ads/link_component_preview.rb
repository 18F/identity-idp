class ADS::LinkComponentPreview < BaseComponentPreview
  # @!group Preview
  def states
  end
  # @!endgroup

  # @param label text
  # @param url text
  def workbench(label: 'Create an account', url: '#')
    render(ADS::LinkComponent.new(url:).with_content(label))
  end
end
