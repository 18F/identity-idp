module Idv
  module InPerson
    module Public
      class AddressSearchController < ApplicationController
        skip_forgery_protection if: :should_skip_forgery_protection?
  
        def index
          addresses = geocoder.find_address_candidates(SingleLine: '')
  
          render json: addresses.to_json
        end
  
        protected
  
        def geocoder
          ArcgisApi::Mock::Geocoder.new
        end

        def should_skip_forgery_protection?
          IdentityConfig.store.in_person_enable_public_address_search
        end
      end
    end
  end
end
