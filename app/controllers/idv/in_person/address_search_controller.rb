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
        suggestion = geocoder.suggest(search_term).first
        # this happens multiple times
        if !suggestion
          analytics.idv_in_person_location_searched(success: false, error: 'No address candidates found by arcgis')
        end
        return [] unless suggestion
        geocoder.find_address_candidates(suggestion.magic_key).slice(0, 1)

      rescue Faraday::ConnectionFailed
        []
      end

      def geocoder
        @geocoder ||= ArcgisApi::Geocoder.new
      end
    end
  end
end
