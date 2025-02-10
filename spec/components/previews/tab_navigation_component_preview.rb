class TabNavigationComponentPreview < BaseComponentPreview
  # @!group Preview
  def default
    render TabNavigationComponent.new(
      label: 'Navigation',
      routes: [
        { path: lookbook_path('preview'), text: 'Preview' },
        { path: lookbook_path('workbench'), text: 'Workbench' },
      ],
    )
  end
  # @!endgroup

  # @param label text
  def workbench(label: 'Navigation')
    render TabNavigationComponent.new(
      label:,
      routes: [
        { path: lookbook_path('preview'), text: 'Preview' },
        { path: lookbook_path('workbench'), text: 'Workbench' },
      ],
    )
  end

  private

  def lookbook_path(example)
    Lookbook::Engine.routes.url_helpers.lookbook_preview_path("tab_navigation/#{example}")
  end
end
