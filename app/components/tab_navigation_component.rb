class TabNavigationComponent < BaseComponent
  attr_reader :label, :routes, :tag_options

  def initialize(label:, routes:, **tag_options)
    @label = label
    @routes = routes
    @tag_options = tag_options
  end
end
