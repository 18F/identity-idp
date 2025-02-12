# frozen_string_literal: true

class TabNavigationComponent < BaseComponent
  attr_reader :label, :routes, :tag_options

  def initialize(label:, routes:, **tag_options)
    @label = label
    @routes = routes
    @tag_options = tag_options
  end

  def current_path?(path)
    @current_path ||= {}
    if !@current_path.key?(path)
      @current_path[path] = begin
        recognized_path = Rails.application.routes.recognize_path(path, method: request.method)
        request.params[:controller] == recognized_path[:controller] &&
          request.params[:action] == recognized_path[:action]
      rescue ActionController::RoutingError
        false
      end
    end

    @current_path[path]
  end

  private

  def nav_list_item(route, &block)
    if current_path?(route[:path])
      render(
        ClickObserverComponent.new(
          event_name: 'tab_navigation_current_page_clicked',
          payload: { path: route[:path] },
          role: 'listitem',
          class: 'usa-button-group__item display-list-item',
        ),
        &block
      )
    else
      tag.li(class: 'usa-button-group__item', &block)
    end
  end
end
