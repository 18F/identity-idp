module NDS
  # Net-new NDS page footer chrome; only renders in the NDS layout. Add
  # ?ui_test_bucket=nds to the preview URL to load the NDS styles and see it.
  # The language/destination selects and help link render via the
  # bucket-conditional ButtonComponent (quaternary in the nds bucket).
  class PageFooterChromeComponentPreview < BaseComponentPreview
    def default
      render(NDS::PageFooterChromeComponent.new)
    end
  end
end
