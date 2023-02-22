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

      def api_status_from_error(err)
        if err.instance_of?(Faraday::ClientError)
          :bad_request
        elsif err.instance_of?(Faraday::ConnectionFailed)
          :bad_gateway
        elsif err.instance_of?(Faraday::TimeoutError)
          :gateway_timeout
        else
          :internal_server_error
        end
      end

      def addresses(search_term)
        addresses = geocoder.find_address_candidates(SingleLine: search_term).slice(0, 1)
        if addresses.empty?
          analytics.idv_in_person_locations_searched(
            success: false, errors: 'No address candidates found by ArcGIS',
          )
        end

        { json: addresses, status: :ok }
      rescue StandardError => err
        api_status = api_status_from_error(err)
        api_status_code = Rack::Utils::SYMBOL_TO_STATUS_CODE[api_status]
        exception_message = err.message
        response_status_code = err.respond_to?(:response_status) && err.response_status
        errors = if err.instance_of?(Faraday::ClientError)
                   err.response_body && err.response_body[:details]
                 end
        errors ||= 'ArcGIS error performing operation'

        # log search event
        analytics.idv_in_person_locations_searched(
          success: false,
          errors: errors,
          api_status_code: api_status_code,
          exception_class: err.class,
          exception_message: exception_message,
          response_status_code: response_status_code,
        )

        # log the request failure
        analytics.idv_arcgis_request_failure(
          exception_class: err.class,
          exception_message: exception_message,
          response_body_present: err.respond_to?(:response_body) && err.response_body.present?,
          response_body: err.respond_to?(:response_body) && err.response_body,
          response_status_code: response_status_code,
          api_status_code: api_status_code,
        )

        { json: [], status: api_status }
      end

      def geocoder
        @geocoder ||= IdentityConfig.store.arcgis_mock_fallback ?
          ArcgisApi::Mock::Geocoder.new : ArcgisApi::Geocoder.new
      end
    end
  end
end
