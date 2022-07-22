require 'json'

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController
      def index
        begin
          usps_response = UspsInPersonProofer.new.request_pilot_facilities
        rescue Faraday::ConnectionFailed => error
          print error
        end

        render body: usps_response.to_json, content_type: 'application/json'
      end
    end
  end
end
