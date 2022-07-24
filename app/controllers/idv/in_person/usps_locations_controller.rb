require 'json'

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController
      include UspsInPersonProofing

      # get the list of all pilot Post Office locations
      def index
        begin
          usps_response = Proofer.new.request_pilot_facilities
        rescue Faraday::ConnectionFailed => _error
          # TODO: handle this error and show "No locations found" on the front end
          nil
        end

        render body: usps_response.to_json, content_type: 'application/json'
      end

      # save the Post Office location the user selected to the session
      def update
        render json: { success: true }, status: :ok
      end

      # return the Post Office location the user selected from the session
      def show
      end
    end
  end
end
