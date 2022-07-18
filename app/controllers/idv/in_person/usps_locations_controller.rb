require "json"

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController

      def index
        begin 
          uspsResponse = UspsInPersonProofer.new.request_pilot_facilities()
        rescue Faraday::ConnectionFailed => error
          print error
        end

        render body: uspsResponse.to_json, content_type: 'application/json'
      end
    end
  end
end
