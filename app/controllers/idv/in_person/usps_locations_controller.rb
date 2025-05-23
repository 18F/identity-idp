# frozen_string_literal: true

require 'json'

module Idv
  module InPerson
    class UspsLocationsError < StandardError
      def initialize
        super('Unsupported characters in address field.')
      end
    end

    class UspsLocationsController < ApplicationController
      include Idv::AvailabilityConcern
      include Idv::HybridMobile::HybridMobileConcern
      include RenderConditionConcern
      include UspsInPersonProofing
      include IppHelper

      check_or_render_not_found -> { InPersonConfig.enabled? }

      before_action :confirm_authenticated_for_api, only: [:update]

      rescue_from ActionController::InvalidAuthenticityToken,
                  Faraday::Error,
                  StandardError,
                  UspsLocationsError,
                  Faraday::BadRequestError,
                  with: :handle_error

      # retrieve the list of nearby IPP Post Office locations with a POST request
      def index
        candidate = UspsInPersonProofing::Applicant.new(
          address: search_params['street_address'],
          city: search_params['city'], state: search_params['state'],
          zip_code: search_params['zip_code']
        )

        unless candidate.has_valid_address?
          raise UspsLocationsError.new
        end

        locations = proofer.request_facilities(candidate, authn_context_enhanced_ipp?)
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
          selected_location_details: update_location,
          issuer: current_sp&.issuer,
          doc_auth_result: document_capture_session&.last_doc_auth_result,
          sponsor_id: enrollment_sponsor_id,
          document_type: nil,
        )

        render json: { success: true }, status: :ok
      end

      def idv_session
        if user_session && current_user
          @idv_session ||= Idv::Session.new(
            user_session: user_session,
            current_user: current_user,
            service_provider: current_sp,
          )
        end
      end

      private

      def document_capture_session
        if idv_session&.document_capture_session_uuid # standard flow
          DocumentCaptureSession.find_by(uuid: idv_session.document_capture_session_uuid)
        else # hybrid flow
          super
        end
      end

      def proofer
        @proofer ||= EnrollmentHelper.usps_proofer
      end

      def localized_locations(locations)
        return nil if locations.nil?
        locations.map do |location|
          EnrollmentHelper.localized_location(location)
        end
      end

      def handle_error(err)
        # Due to app-wide level alarms triggering on 5XX error codes, we are
        # only returning 5XX error codes in the case of an 'unhandled' scenario.
        # When diving into error logs for this controller trust exception_class
        # and exception_message over api_status_code as the codes are misleading.
        remapped_error = case err
                         when ActionController::InvalidAuthenticityToken,
                              Faraday::Error,
                              UspsLocationsError
                           :unprocessable_entity
                         else
                           :internal_server_error
                         end

        # Below, the api_status_code is our internally remapped error code,
        # while response_status_code is the status code returned from the USPS
        # endpoint itself.
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

      def enrollment_sponsor_id
        authn_context_enhanced_ipp? ?
          IdentityConfig.store.usps_eipp_sponsor_id :
          IdentityConfig.store.usps_ipp_sponsor_id
      end

      def authn_context_enhanced_ipp?
        resolved_authn_context_result.enhanced_ipp?
      end

      # Handles selecting proper update_location method based on 50/50 state
      def update_location
        legacy_update_location_request? ?
          legacy_update_location :
          updated_update_location['selected_location']
      end

      def legacy_update_location
        params.require(:usps_location).permit(
          :formatted_city_state_zip,
          :name,
          :saturday_hours,
          :street_address,
          :sunday_hours,
          :weekday_hours,
        ).as_json
      end

      def updated_update_location
        params.require(:usps_location).permit(
          selected_location:
            [
              :formatted_city_state_zip,
              :name, :saturday_hours,
              :street_address,
              :sunday_hours,
              :weekday_hours
            ],
        ).with_defaults(selected_location: nil).as_json
      end

      def legacy_update_location_request?
        params.require(:usps_location).exclude?(:selected_location)
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
