require "json"

module Idv
  module InPerson
    class UspsLocationsController < ApplicationController

      TransformedLocation = Struct.new(:name, :streetAddress, :addressLine2, :weekdayHours, :saturdayHours, :sundayHours)

      def index
        transformedData = transformJson(parseJsonResponse)
        render body: transformedData, content_type: 'application/json'
      end

      private
      def parseJsonResponse
        # TODO: get response from UspsInPersonProofer#request_facilities
        file = File.open "spec/fixtures/usps_ipp_responses/request_facilities_response.json"
        data = JSON.load file
        dataJson = data.to_json
        parsedJson = JSON.parse(dataJson)
      end

      # TODO: update data transformation as this file should get an array of structs rather than json  
      private
      # rename 
      def formatAddressline(location)
        addyLine = "#{location["city"]}, #{location["state"]} #{location["zip4"]}-#{location["zip5"]}"
      end

      private
      def transformJson(json)
        transformedLocations = Array.new()
        
        for item in json["postOffices"] do
          location = TransformedLocation.new(item["name"], item["streetAddress"], formatAddressline(item), item["hours"][0]["weekdayHours"], item["hours"][1]["saturdayHours"], item["hours"][2]["sundayHours"])
          transformedLocations.push(location)
        end

       transformedLocations.to_json
      end

    end
  end
end
