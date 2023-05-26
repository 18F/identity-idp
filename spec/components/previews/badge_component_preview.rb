class BadgeComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(BadgeComponent.new(icon: :success).with_content('Verified Account'))
  end
  # @!endgroup

  # @param icon select [success,unphishable]
  # @param content text
  def workbench(icon: :success, content: 'Verified Account')
    render(BadgeComponent.new(icon: icon&.to_sym).with_content(content))
  end
end
