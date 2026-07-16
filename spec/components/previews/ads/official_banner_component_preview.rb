class ADS::OfficialBannerComponentPreview < BaseComponentPreview
  # @!group Preview
  def preview
  end
  # @!endgroup

  def workbench
    render(ADS::OfficialBannerComponent.new)
  end
end
