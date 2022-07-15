require "json"

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController

      def index
         #TODO: uncomment when we have credentials to use api
      #   defaultAddress = Location.new(address: "1600 Pennsylvania Avenue NW",
      #   city: "Washington",
      #   state: "DC",
      #   zip_code: "")

        # begin 
        #   uspsResponse = UspsInPersonProofer.new.request_facilities(defaultAddress)
        # rescue Faraday::ConnectionFailed => error
        #   print error
        # end
      
        render body: parseJsonResponse, content_type: 'application/json'
      end


      private
      def parseJsonResponse
        # TODO: remove when we have credentials for api
        file = File.open "spec/fixtures/usps_ipp_responses/request_facilities_response.json"
        data = JSON.load file
        dataJson = data.to_json
      end

    end
  end
end
