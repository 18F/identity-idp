module Idv
  module InPerson
    class AddressSearchController < ApplicationController
      include RenderConditionConcern

      check_or_render_not_found -> { IdentityConfig.store.arcgis_search_enabled }

      rescue_from Faraday::ConnectionFailed, Faraday::TimeoutError, with: :report_errors

      def index
        response = addresses(params[:address])

        render(**response)
      end

      protected

      def addresses(search_term)
        addresses = geocoder.find_address_candidates(SingleLine: search_term).slice(0, 1)

        { json: addresses, status: :ok }
      end

      def geocoder
        @geocoder ||= IdentityConfig.store.arcgis_mock_fallback ?
          ArcgisApi::Mock::Geocoder.new : ArcgisApi::Geocoder.new
      end

      def report_errors(error)
        remapped_error = {
          Faraday::ConnectionFailed => :unprocessable_entity,
          Faraday::TimeoutError => :unprocessable_entity,
        }[error.class] || :internal_server_error

        analytics.idv_arcgis_request_failure(
          api_status_code: Rack::Utils.status_code(remapped_error),
          exception_class: error.class,
          exception_message: error.message,
          response_body_present: error.respond_to?(:response_body) && error.response_body.present?,
          response_body: error.respond_to?(:response_body) && error.response_body,
          response_status_code: error.respond_to?(:response_status) && error.response_status,
        )
        render json: [], status: remapped_error
      end
    end
  end
end
