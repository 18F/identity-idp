# frozen_string_literal: true

require 'json'

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController
      include Idv::AvailabilityConcern
      include Idv::HybridMobile::HybridMobileConcern
      include RenderConditionConcern
      include UspsInPersonProofing

      check_or_render_not_found -> { InPersonConfig.enabled? }

      before_action :confirm_authenticated_for_api, only: [:update]

      rescue_from ActionController::InvalidAuthenticityToken,
                  Faraday::Error,
                  StandardError,
                  with: :handle_error

      # retrieve the list of nearby IPP Post Office locations with a POST request
      def index
        candidate = UspsInPersonProofing::Applicant.new(
          address: search_params['street_address'],
          city: search_params['city'], state: search_params['state'],
          zip_code: search_params['zip_code']
        )
        is_enhanced_ipp = resolved_authn_context_result.enhanced_ipp?
        locations = proofer.request_facilities(candidate, is_enhanced_ipp)
        if locations.length > 0
          analytics.idv_in_person_locations_searched(
            success: true,
            result_total: locations.length,
          )
        else
          analytics.idv_in_person_locations_searched(
            success: false, errors: 'No USPS locations found',
          )
        end
        render json: localized_locations(locations).to_json
      end

      # save the Post Office location the user selected to an enrollment
      def update
        enrollment.update!(
          selected_location_details: update_params.as_json,
          issuer: current_sp&.issuer,
        )
        add_proofing_component

        render json: { success: true }, status: :ok
      end

      private

      def proofer
        @proofer ||= EnrollmentHelper.usps_proofer
      end

      def add_proofing_component
        ProofingComponent.
          create_or_find_by(user: current_or_hybrid_user).
          update(document_check: Idp::Constants::Vendors::USPS)
      end

      def localized_locations(locations)
        return nil if locations.nil?
        locations.map do |location|
          EnrollmentHelper.localized_location(location)
        end
      end

      def handle_error(err)
        remapped_error = case err
                         when ActionController::InvalidAuthenticityToken,
                              Faraday::Error
                           :unprocessable_entity
                         else
                           :internal_server_error
                         end

        analytics.idv_in_person_locations_request_failure(
          api_status_code: Rack::Utils.status_code(remapped_error),
          exception_class: err.class,
          exception_message: err.message,
          response_body_present: err.respond_to?(:response_body) && err.response_body.present?,
          response_body: err.respond_to?(:response_body) && err.response_body,
          response_status_code: err.respond_to?(:response_status) && err.response_status,
        )
        render json: {}, status: remapped_error
      end

      def confirm_authenticated_for_api
        render json: { success: false }, status: :unauthorized if !current_or_hybrid_user
      end

      def enrollment
        InPersonEnrollment.find_or_initialize_by(
          user: current_or_hybrid_user,
          status: :establishing,
          profile: nil,
        )
      end

      def search_params
        params.require(:address).permit(
          :street_address,
          :city,
          :state,
          :zip_code,
        )
      end

      def update_params
        params.require(:usps_location).permit(
          :formatted_city_state_zip,
          :name,
          :saturday_hours,
          :street_address,
          :sunday_hours,
          :weekday_hours,
        )
      end
    end
  end
end
