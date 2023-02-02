module Idv
  module InPerson
    class AddressSearchController < ApplicationController
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.arcgis_search_enabled }

      def index
        response = addresses(params[:address])
        render(**response)
      end

      protected

      def addresses(search_term)
        suggestion = geocoder.suggest(search_term).first
        return { json: [], status: :ok } unless suggestion
        addresses = geocoder.find_address_candidates(suggestion.magic_key).slice(0, 1)
        { json: addresses, status: :ok }
      rescue Faraday::ConnectionFailed => err
        analytics.idv_arcgis_request_failure(
          api_status_code: 422,
          exception_class: err.class,
          exception_message: err.message,
          response_body_present: err.respond_to?(:response_body) && err.response_body.present?,
          response_body: err.respond_to?(:response_body) && err.response_body,
          response_status_code: err.respond_to?(:response_status) && err.response_status,
        )
        { json: [], status: :unprocessable_entity }
      rescue Faraday::TimeoutError => err
        analytics.idv_arcgis_request_failure(
          api_status_code: 422,
          exception_class: err.class,
          exception_message: err.message,
          response_body_present: err.respond_to?(:response_body) && err.response_body.present?,
          response_body: err.respond_to?(:response_body) && err.response_body,
          response_status_code: err.respond_to?(:response_status) && err.response_status,
        )
        { json: [], status: :unprocessable_entity }
      end

      def geocoder
        @geocoder ||= IdentityConfig.store.arcgis_mock_fallback ?
          ArcgisApi::Mock::Geocoder.new : ArcgisApi::Geocoder.new
      end
    end
  end
end
