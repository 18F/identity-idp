require 'json'

module Idv
  module InPerson
    class AddressSearchController < ApplicationController
      include RenderConditionConcern

      check_or_render_not_found -> { InPersonConfig.enabled? }

      def index
        render json: addresses
      end

      protected

      def addresses
        suggestion = geocoder.suggest(permitted_params[:address]).first
        [geocoder.find_address_candidates(suggestion.magic_key).first]
      rescue Faraday::ConnectionFailed => _error
        []
      end

      def geocoder
        @geocoder ||= ArcgisApi::Geocoder.new
      end

      def permitted_params
        params.permit(:address)
      end
    end
  end
end
