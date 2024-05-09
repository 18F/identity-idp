class BadgeComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render(BadgeComponent.new(icon: :check_circle).with_content('Verified Account'))
  end
  # @!endgroup

  # @param icon select [check_circle,lock]
  # @param content text
  def workbench(icon: :check_circle, content: 'Verified Account')
    render(BadgeComponent.new(icon: icon&.to_sym).with_content(content))
  end
end
