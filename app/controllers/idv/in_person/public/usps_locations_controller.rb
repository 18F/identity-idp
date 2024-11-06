# frozen_string_literal: true

module Idv
  module InPerson
    module Public
      class UspsLocationsError < StandardError
        def initialize
          super('Unsupported characters in address field.')
        end
      end

      class UspsLocationsController < ApplicationController
        skip_forgery_protection

        include IppHelper

        rescue_from ActionController::InvalidAuthenticityToken,
                    Faraday::Error,
                    StandardError,
                    UspsLocationsError,
                    Faraday::BadRequestError,
                    with: :handle_error

        def index
          candidate = UspsInPersonProofing::Applicant.new(
            address: search_params['street_address'],
            city: search_params['city'], state: search_params['state'],
            zip_code: search_params['zip_code']
          )

          unless candidate.has_valid_address?
            raise UspsLocationsError.new
          end

          locations = proofer.request_facilities(candidate, false)

          render json: localized_locations(locations).to_json
        end

        def options
          head :ok
        end

        private

        def proofer
          @proofer ||= UspsInPersonProofing::EnrollmentHelper.usps_proofer
        end

        def localized_locations(locations)
          return nil if locations.nil?
          locations.map do |location|
            UspsInPersonProofing::EnrollmentHelper.localized_location(location)
          end
        end

        def handle_error(err)
          remapped_error = case err
                           when ActionController::InvalidAuthenticityToken,
                                Faraday::Error,
                                UspsLocationsError
                             :unprocessable_entity
                           else
                             :internal_server_error
                           end

          analytics.idv_in_person_locations_request_failure(
            api_status_code: Rack::Utils.status_code(remapped_error),
            exception_class: err.class,
            exception_message: scrub_message(err.message),
            response_body_present: err.respond_to?(:response_body) && err.response_body.present?,
            response_body: err.respond_to?(:response_body) && scrub_body(err.response_body),
            response_status_code: err.respond_to?(:response_status) && err.response_status,
          )
          render json: {}, status: remapped_error
        end

        def search_params
          params.require(:address).permit(
            :street_address,
            :city,
            :state,
            :zip_code,
          )
        end
      end
    end
  end
end
