module Redirect
  class RedirectController < ApplicationController
    PERMITTED_LOCATION_PARAMS = [:flow, :step, :location].freeze

    private

    def location_params
      params.permit(*PERMITTED_LOCATION_PARAMS).to_h.symbolize_keys
    end

    def redirect_to_and_log(url, event: nil, tracker_method: analytics.method(:external_redirect))
      if event
        # Once all events have been moved to tracker methods, we can remove the event: param
        analytics.track_event(event, redirect_url: url, **location_params)
      else
        tracker_method.call(redirect_url: url, **location_params)
      end
      redirect_to(url)
    end
  end
end
