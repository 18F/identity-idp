module Idv
    # is there supposed to be an IPP module declared here?
    class UspsLocationsController < ApplicationController
      def index
        # get response from UspsInPersonProofer
        render body: "{message: 'hello'}", content_type: 'application/json'
      end

      private

      def formatLocation
        # transform the multiple pieces of loc. data to create 2nd addy line
      end
  end
  