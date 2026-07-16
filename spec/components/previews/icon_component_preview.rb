class IconComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  # @param icon select :icon_names
  # @param size select [16,20,24,40]
  # @param label text
  def workbench(icon: :star_filled, size: 24, label: nil)
    render(IconComponent.new(icon: icon.to_sym, size:, label:))
  end

  private

  def icon_names
    IconComponent::REGISTRY.keys.map(&:to_s)
  end
end
