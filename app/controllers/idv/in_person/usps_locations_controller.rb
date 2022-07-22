require 'json'

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController
      include UspsInPersonProofing
      def index
        begin
          usps_response = Proofer.new.request_pilot_facilities
        rescue Faraday::ConnectionFailed => error
          print error
        end

        render body: usps_response.to_json, content_type: 'application/json'
      end
    end
  end
end
