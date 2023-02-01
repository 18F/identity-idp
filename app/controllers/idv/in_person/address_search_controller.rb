module Idv
  module InPerson
    class AddressSearchController < ApplicationController
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.arcgis_search_enabled }

      def index
        render json: addresses(params[:address])
      end

      protected

      def addresses(search_term)
        geocoder.find_address_candidates(SingleLine: search_term).slice(0, 1)
      rescue Faraday::ConnectionFailed
        []
      end

      def geocoder
        @geocoder ||= IdentityConfig.store.arcgis_mock_fallback ?
          ArcgisApi::Mock::Geocoder.new : ArcgisApi::Geocoder.new
      end
    end
  end
end
