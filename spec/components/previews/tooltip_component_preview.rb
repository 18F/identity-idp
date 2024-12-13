class TooltipComponentPreview < BaseComponentPreview
  # @!group Preview
  # @display body_class padding-10
  def default
    render(
      TooltipComponent
        .new(tooltip_text: 'Finish verifying your identity.')
        .with_content(content_tag(:span, 'Unverified')),
    )
  end
  # @!endgroup

  # @param content text
  # @param tooltip_text text
  # @display body_class padding-10
  def workbench(
    content: 'Unverified',
    tooltip_text: 'Finish verifying your identity.'
  )
    render(TooltipComponent.new(tooltip_text:).with_content(content_tag(:span, content)))
  end
end
