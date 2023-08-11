module Idv
  module InPerson
    class AddressSearchController < ApplicationController
      rescue_from ActionController::InvalidAuthenticityToken,
                  Faraday::Error,
                  StandardError,
                  with: :report_errors

      def index
        response = addresses(params[:address])

        render(**response)
      end

      protected

      def addresses(search_term)
        addresses = geocoder.find_address_candidates(SingleLine: search_term).slice(0, 1)
        if addresses.empty?
          analytics.idv_in_person_locations_searched(
            success: false, errors: 'No address candidates found by ArcGIS',
          )
        end

        { json: addresses, status: :ok }
      end

      def geocoder
        @geocoder ||= ArcgisApi::GeocoderFactory.new.create
      end

      def report_errors(error)
        remapped_error = case error
                         when Faraday::Error,
                              ActionController::InvalidAuthenticityToken
                           :unprocessable_entity
                         else
                           :internal_server_error
                         end

        errors = if error.respond_to?(:response_body)
                   error.response_body.is_a?(Hash) && error.response_body[:details]
                 end

        errors ||= 'ArcGIS error performing operation'

        analytics.idv_in_person_locations_searched(
          success: false,
          errors: errors,
          api_status_code: Rack::Utils.status_code(remapped_error),
          exception_class: error.class,
          exception_message: error.message,
          response_status_code: error.try(:response_status),
        )

        analytics.idv_arcgis_request_failure(
          api_status_code: Rack::Utils.status_code(remapped_error),
          exception_class: error.class,
          exception_message: error.message,
          response_body_present: error.respond_to?(:response_body) && error.response_body.present?,
          response_body: error.respond_to?(:response_body) && error.response_body,
          response_status_code: error.try(:response_status),
        )
        render json: [], status: remapped_error
      end
    end
  end
end
