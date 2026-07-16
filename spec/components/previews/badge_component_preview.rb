class BadgeComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param content text
  # @param variant select [primary,secondary,tertiary,success,error,warning]
  # @param icon select [~,plus]
  def workbench(
    content: 'Label',
    variant: :primary,
    icon: nil
  )
    render(
      BadgeComponent.new(
        variant: variant.to_sym,
        icon: icon&.to_sym,
      ).with_content(content),
    )
  end
end
