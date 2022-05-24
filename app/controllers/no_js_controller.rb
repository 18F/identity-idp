class NoJsController < ApplicationController
  SESSION_KEY = :no_js_css

  def css
    session[SESSION_KEY] = true
    render body: '', content_type: 'text/css'
  end
end
