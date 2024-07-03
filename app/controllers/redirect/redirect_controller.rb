# frozen_string_literal: true

module Redirect
  class RedirectController < ApplicationController
    PERMITTED_LOCATION_PARAMS = [:flow, :step, :location].freeze

    private

    def location_params
      params.permit(*PERMITTED_LOCATION_PARAMS).to_h.symbolize_keys
    end

    def partner_params
      {
        agency: current_sp&.agency&.name,
        integration: current_sp&.integration&.name,
      }.compact
    end

    def partner_query_params(url)
      UriService.add_params(url, partner_params)
    end

    def redirect_to_and_log(url, event: nil, tracker_method: analytics.method(:external_redirect))
      if event
        # Once all events have been moved to tracker methods, we can remove the event: param
        analytics.track_event(event, redirect_url: url, **location_params)
      else
        tracker_method.call(redirect_url: url, **location_params)
      end

      redirect_url = partner_query_params(url)
      redirect_to(redirect_url, allow_other_host: true)
    end
  end
end
