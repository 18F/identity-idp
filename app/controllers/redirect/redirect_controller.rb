module Redirect
  class RedirectController < ApplicationController
    PERMITTED_LOCATION_PARAMS = [:flow, :step, :location].freeze

    private

    def location_params
      params.permit(*PERMITTED_LOCATION_PARAMS).to_h.symbolize_keys
    end

    def redirect_to_and_log(url, event: Analytics::EXTERNAL_REDIRECT)
      analytics.track_event(event, redirect_url: url, **location_params)
      redirect_to(url)
    end
  end
end
