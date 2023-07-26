module Idv
  module InPerson
    module Public
      class MockAddressSearchController < ApplicationController
        protect_from_forgery with: :null_session
  
        def addresses
          addresses = geocoder.find_address_candidates(SingleLine: '')
  
          render json: addresses.to_json
        end
  
        def usps_locations
          locations = proofer.request_facilities('')
          render json: locations.to_json
        end
  
        protected
  
        def geocoder
          ArcgisApi::Mock::Geocoder.new
        end

        def proofer
          UspsInPersonProofing::Mock::Proofer.new
        end
      end
    end
  end
end
