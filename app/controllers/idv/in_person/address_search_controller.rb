require 'json'

module Idv
  module InPerson
    class AddressSearchController < ApplicationController
      include RenderConditionConcern

      check_or_render_not_found -> { InPersonConfig.enabled? }

      def index
        arcgis_api_response = []
        begin
          suggestion = geocoder.suggest(permitted_params[:address]).first
          arcgis_api_response = [geocoder.find_address_candidates(suggestion.magic_key).first]
        rescue Faraday::ConnectionFailed => _error
          nil
        end

        render json: arcgis_api_response
      end

      protected

      def geocoder
        @geocoder ||= ArcgisApi::Geocoder.new
      end

      def permitted_params
        params.permit(:address)
      end
    end
  end
end
