# frozen_string_literal: true

class TabNavigationComponent < BaseComponent
  attr_reader :label, :routes, :tag_options

  def initialize(label:, routes:, **tag_options)
    @label = label
    @routes = routes
    @tag_options = tag_options
  end

  def current_path?(path)
    recognized_path = Rails.application.routes.recognize_path(path, method: request.method)
    request.params[:controller] == recognized_path[:controller] &&
      request.params[:action] == recognized_path[:action]
  rescue ActionController::RoutingError
    false
  end
end
