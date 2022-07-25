require 'json'

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController
      include IdvSession
      include UspsInPersonProofing

      # get the list of all pilot Post Office locations
      def index
        begin
          usps_response = Proofer.new.request_pilot_facilities
        rescue Faraday::ConnectionFailed => _error
          # TODO: handle this error and show "No locations found" on the front end
          nil
        end

        render json: usps_response.to_json
      end

      # save the Post Office location the user selected to the session
      def update
        idv_session.applicant ||= {}
        idv_session.applicant[:selected_location_details] = permitted_params.as_json

        render json: { success: true }, status: :ok
      end

      # return the Post Office location the user selected from the session
      def show
        selected_location = idv_session.applicant&.[](:selected_location_details)&.to_json || {}

        render json: selected_location, status: :ok
      end

      protected

      def permitted_params
        params.require(:usps_location).permit(
          :addressLine2,
          :name,
          :phone,
          :saturdayHours,
          :streetAddress,
          :sundayHours,
          :weekdayHours,
        )
      end
    end
  end
end
