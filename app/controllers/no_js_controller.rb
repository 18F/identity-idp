class NoJsController < ApplicationController
  SESSION_KEY = :no_js_css

  def index
    session[SESSION_KEY] = true
    render body: '', content_type: 'text/css'
  end
end
