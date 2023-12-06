class NoJsController < ApplicationController
  SESSION_KEY = :no_js_css

  def index
    session[SESSION_KEY] = true
    analytics.no_js_detect_stylesheet_loaded(location: params[:location])
    render body: '', content_type: 'text/css'
  end
end
