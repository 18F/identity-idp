require 'json'

module Idv
  module InPerson
    class AddressSearchController < ApplicationController
      include ArcgisApi

      def geocoder
        @geocoder ||= Geocoder.new
      end

      def suggest(address)
        geocoder.suggest(address)
      end

      def find_address_candidates(magic_key)
        geocoder.find_address_candidates(magic_key)
      end

      def index
        arcgis_api_response = []
        begin
          suggestion = suggest(permitted_params[:address]).first
          arcgis_api_response = [find_address_candidates(suggestion.magic_key).first]
        rescue Faraday::ConnectionFailed => _error
          nil
        end

        render json: arcgis_api_response.to_json
      end

      protected

      def permitted_params
        params.permit(:address)
      end
    end
  end
end
