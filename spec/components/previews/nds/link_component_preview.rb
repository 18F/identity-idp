module NDS
  # Net-new NDS link primitive; only renders in the NDS layout. Add
  # ?ui_test_bucket=nds to the preview URL to load the NDS styles and see it.
  class LinkComponentPreview < BaseComponentPreview
    def default
      render(NDS::LinkComponent.new(url: '#').with_content('Manage your account'))
    end

    def external
      render(
        NDS::LinkComponent.new(url: 'https://login.gov', target: '_blank')
          .with_content('Open login.gov'),
      )
    end

    def nowrap
      render(
        NDS::LinkComponent.new(url: '#', class: 'link--nowrap')
          .with_content('Do not wrap this link'),
      )
    end

    # @param content text
    # @param nowrap toggle
    def workbench(content: 'Manage your account', nowrap: false)
      render(
        NDS::LinkComponent.new(url: '#', class: ('link--nowrap' if nowrap))
          .with_content(content),
      )
    end
  end
end
