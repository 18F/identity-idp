class ButtonComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param content text
  # @param variant select [primary,secondary,tertiary,quaternary,ghost,destructive]
  # @param size select [lg,md,sm]
  # @param icon select [~,plus,print,content_copy]
  # @param icon_position select [left,right]
  # @param disabled toggle
  def workbench(
    content: 'Label',
    variant: :primary,
    size: :lg,
    icon: nil,
    icon_position: :left,
    disabled: false
  )
    render(
      ButtonComponent.new(
        variant: variant.to_sym,
        size: size.to_sym,
        icon: icon&.to_sym,
        icon_position: icon_position.to_sym,
        disabled:,
      ).with_content(content),
    )
  end
end
