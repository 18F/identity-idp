module Idv
  module InPerson
    module Public
      class MockAddressSearchController < ApplicationController
        skip_forgery_protection if: :should_skip_forgery_protection?
  
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

        def should_skip_forgery_protection?
          IdentityConfig.store.in_person_enable_public_address_search
        end
      end
    end
  end
end
