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

      def set_api_status_code(err)
        if err.instance_of?(Faraday::ClientError)
          return err.response['error']['code']
        elsif err.instance_of?(Faraday::ConnectionFailed) || err.instance_of?(Faraday::TimeoutError)
          return Rack::Utils::SYMBOL_TO_STATUS_CODE[:unprocessable_entity]
        else
          return 500
        end
      end

      def addresses(search_term)
        addresses = geocoder.find_address_candidates(SingleLine: search_term).slice(0, 1)
        if addresses.empty?
          analytics.idv_in_person_locations_searched(
            success: false, errors: 'No address candidates found by arcgis',
          )
        end
        { json: addresses, status: :ok }
      rescue StandardError => err
        apiError = err.instance_of?(Faraday::ClientError) ? err.response['error'] : nil
        # log search event for all errors
        analytics.idv_in_person_locations_searched(
          success: false,
          errors: apiError ? apiError['details'] : 'Arcgis error performing operation',
          api_status_code: set_api_status_code(err),
          exception_class: err.class,
          exception_message: apiError ? apiError['message'] : err.message,
          response_status_code: err.respond_to?(:response_status) && err.response_status,
        )
        api_status = apiError ? :bad_request : :internal_server_error
        # log the request failure
        if err.instance_of?(Faraday::ConnectionFailed) || err.instance_of?(Faraday::TimeoutError)
          api_status = :unprocessable_entity
          analytics.idv_arcgis_request_failure(
            api_status_code: set_api_status_code(err),
            exception_class: err.class,
            exception_message: err.message,
            response_body_present: err.respond_to?(:response_body) && err.response_body.present?,
            response_body: err.respond_to?(:response_body) && err.response_body,
            response_status_code: err.respond_to?(:response_status) && err.response_status,
          )
        end
        { json: [], status: api_status }
      end

      def geocoder
        @geocoder ||= IdentityConfig.store.arcgis_mock_fallback ?
          ArcgisApi::Mock::Geocoder.new : ArcgisApi::Geocoder.new
      end
    end
  end
end
