require 'json'

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController
      include RenderConditionConcern
      include UspsInPersonProofing
      include EffectiveUser

      check_or_render_not_found -> { InPersonConfig.enabled? }

      before_action :confirm_authenticated_for_api, only: [:update]

      # retrieve the list of nearby IPP Post Office locations with a POST request
      def index
        usps_response = []
        begin
          if IdentityConfig.store.arcgis_search_enabled
            candidate = UspsInPersonProofing::Applicant.new(
              address: search_params['street_address'],
              city: search_params['city'],
              state: search_params['state'],
              zip_code: search_params['zip_code'],
            )
            usps_response = proofer.request_facilities(candidate)
          else
            usps_response = proofer.request_pilot_facilities
          end
        rescue ActionController::ParameterMissing
          usps_response = proofer.request_pilot_facilities
        rescue Faraday::ConnectionFailed => _error
          nil
        end

        render json: usps_response.to_json
      end

      def proofer
        @proofer ||= Proofer.new
      end

      # save the Post Office location the user selected to an enrollment
      def update
        enrollment.update!(
          selected_location_details: update_params.as_json,
          issuer: current_sp&.issuer,
        )

        render json: { success: true }, status: :ok
      end

      protected

      def confirm_authenticated_for_api
        render json: { success: false }, status: :unauthorized if !effective_user
      end

      def enrollment
        InPersonEnrollment.find_or_initialize_by(
          user: effective_user,
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
          :phone,
          :saturday_hours,
          :street_address,
          :sunday_hours,
          :weekday_hours,
        )
      end
    end
  end
end
