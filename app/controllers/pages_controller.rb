class PagesController < ApplicationController
  skip_after_action :track_get_requests

  def page_not_found
    analytics.track_event(:page_not_found, path: request.path)

    render layout: false, status: 404
  end

  def privacy_policy
  end
end
