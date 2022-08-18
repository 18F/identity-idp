require 'json'

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController
      include RenderConditionConcern
      include UspsInPersonProofing
      include EffectiveUser

      check_or_render_not_found -> { InPersonConfig.enabled? }

      before_action :confirm_authenticated_for_api, only: [:update]

      # get the list of all pilot Post Office locations
      def index
        usps_response = []
        begin
          usps_response = Proofer.new.request_pilot_facilities
        rescue Faraday::ConnectionFailed => _error
          nil
        end

        render json: usps_response.to_json
      end

      # save the Post Office location the user selected to an enrollment
      def update
        enrollment.update!(
          selected_location_details: permitted_params.as_json,
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

      def permitted_params
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
