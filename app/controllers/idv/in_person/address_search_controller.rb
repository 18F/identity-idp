module Idv
  module InPerson
    class AddressSearchController < ApplicationController
      include ApplicationHelper # for liveness_checking_enabled?

      # include RenderConditionConcern

      # check_or_render_not_found -> { IdentityConfig.store.arcgis_search_enabled }

      respond_to :json

      def index
        render json: addresses(params[:address])
      end

      protected

      def addresses(search_term)
        suggestion = geocoder.suggest(search_term).first
        return [] unless suggestion
        geocoder.find_address_candidates(suggestion.magic_key).slice(0, 1)
      rescue Faraday::ConnectionFailed
        []
      end

      def geocoder
        @geocoder ||= ArcgisApi::Geocoder.new
      end

      # def permitted_params
      #   params.permit(:address)
      # end
    end
  end
end
