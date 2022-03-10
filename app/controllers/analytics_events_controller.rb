# Serve a static file from Rails so that the CORS middleware can add the correct headers
class AnalyticsEventsController < ApplicationController
  prepend_before_action :skip_session_load
  prepend_before_action :skip_session_expiration
  skip_before_action :disable_caching

  JSON_FILE = Rails.root.join('public', 'api', '_analytics-events.json')

  def index
    if File.exist?(JSON_FILE)
      expires_in 15.minutes, public: true

      send_file JSON_FILE, type: 'application/json', disposition: 'inline'
    else
      render_not_found
    end
  end
end
