# frozen_string_literal: true

module Redirect
  class RedirectController < ApplicationController
    PERMITTED_LOCATION_PARAMS = [:flow, :step, :location].freeze

    private

    def location_params
      params.permit(*PERMITTED_LOCATION_PARAMS).to_h.symbolize_keys
    end

    def partner_query_params
      @partner_query_params ||= begin
        {
          partner: current_sp&.agency&.name,
          partner_div: current_sp&.integration&.name,
        }.compact
      end
    end

    def add_partner_query_params(url)
      uri = Addressable::URI.parse(url)

      if partner_query_params.any?
        uri.query_values = (uri.query_values || {}).merge(partner_query_params)
      end

      uri.to_s
    end

    def redirect_to_and_log(url, event: nil, tracker_method: analytics.method(:external_redirect))
      if event
        # Once all events have been moved to tracker methods, we can remove the event: param
        analytics.track_event(event, redirect_url: url, **location_params)
      else
        tracker_method.call(redirect_url: url, **location_params)
      end

      redirect_url = add_partner_query_params(url)
      redirect_to(redirect_url, allow_other_host: true)
    end
  end
end
