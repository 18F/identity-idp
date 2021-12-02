module Redirect
  class RedirectController < ApplicationController
    PERMITTED_LOCATION_PARAMS = [:flow, :step, :location].freeze

    def location_params
      params.permit(*PERMITTED_LOCATION_PARAMS).to_h.symbolize_keys
    end

    def redirect_to_and_log(...)
      redirect_result = redirect_to(...)

      analytics.track_event(
        Analytics::EXTERNAL_REDIRECT,
        redirect_url: self.location,
        **location_params,
      )

      redirect_result
    end
  end
end
