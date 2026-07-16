class ADS::PageFooterChromeComponentPreview < BaseComponentPreview
  # @display body_class "margin-0 padding-0"
  # @display max_width 1440
  def desktop
    render ADS::PageFooterChromeComponent.new
  end

  # @display body_class "margin-0 padding-0"
  # @display max_width 402
  def mobile
    render ADS::PageFooterChromeComponent.new
  end
end
