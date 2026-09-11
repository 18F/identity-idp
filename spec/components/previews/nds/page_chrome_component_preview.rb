module NDS
  # Net-new NDS top chrome; only renders in the NDS layout. Add
  # ?ui_test_bucket=nds to the preview URL to load the NDS styles and see it.
  #
  # The government banner needs full controller/session context not available
  # to Lookbook previews, so these scenarios hide it and show the logo chrome.
  class PageChromeComponentPreview < BaseComponentPreview
    def default
      render(NDS::PageChromeComponent.new(hide_banner: true))
    end

    def without_logo
      render(NDS::PageChromeComponent.new(hide_banner: true, hide_logo: true))
    end

    # @param hide_logo toggle
    def workbench(hide_logo: false)
      render(NDS::PageChromeComponent.new(hide_banner: true, hide_logo:))
    end
  end
end
