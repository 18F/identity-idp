class TabNavigationComponent < BaseComponent
  attr_reader :label, :routes, :tag_options

  def initialize(label:, routes:, **tag_options)
    @label = label
    @routes = routes
    @tag_options = tag_options
  end

  def is_current_path?(path)
    recognized_path = Rails.application.routes.recognize_path(path)
    [recognized_path, request].pluck(:controller, :action).uniq.one?
  rescue ActionController::RoutingError
    false
  end
end
