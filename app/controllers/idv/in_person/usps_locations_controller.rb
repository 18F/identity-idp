require 'json'

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController
      include UspsInPersonProofing
      include EffectiveUser

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
        enrollment.update!(selected_location_details: permitted_params.as_json)

        render json: { success: true }, status: :ok
      end

      protected

      def enrollment
        UspsInPersonProofing::EnrollmentHelper.
          establishing_in_person_enrollment_for_user(effective_user)
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
