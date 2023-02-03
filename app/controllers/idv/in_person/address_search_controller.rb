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
        addresses = geocoder.find_address_candidates(SingleLine: search_term).slice(0, 1)
        if addresses.length < 1
          # multiple logs when no adresses exist
          analytics.idv_in_person_location_searched(
            success: false, errors: 'No address candidates found by arcgis',
          )
          addresses = []
        end
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
      rescue StandardError => err
        analytics.idv_in_person_location_searched(
          success: false,
          errors: 'Arcgis no addresses',
          api_status_code: 500,
          exception_class: err.class,
          exception_message: err.message,
          reason: 'Arcgis error performing operation',
          response_status_code: err.respond_to?(:response_status) && err.response_status,
        )
        { json: [], status: :internal_server_error }
      end

      def geocoder
        @geocoder ||= IdentityConfig.store.arcgis_mock_fallback ?
          ArcgisApi::Mock::Geocoder.new : ArcgisApi::Geocoder.new
      end
    end
  end
end
