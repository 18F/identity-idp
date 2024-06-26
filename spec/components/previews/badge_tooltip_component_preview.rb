class BadgeTooltipComponentPreview < BaseComponentPreview
  # @!group Preview
  # @display body_class padding-10
  def default
    render(
      BadgeTooltipComponent.
        new(icon: :warning, tooltip_text: 'Finish verifying your identity.').
        with_content('Unverified'),
    )
  end
  # @!endgroup

  # @param icon select [check_circle,lock,warning,info]
  # @param content text
  # @param tooltip_text text
  # @display body_class padding-10
  def workbench(
    icon: :warning,
    content: 'Unverified',
    tooltip_text: 'Finish verifying your identity.'
  )
    render(BadgeTooltipComponent.new(icon: icon&.to_sym, tooltip_text:).with_content(content))
  end
end
