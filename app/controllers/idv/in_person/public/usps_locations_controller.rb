module Idv
  module InPerson
    module Public
      class UspsLocationsController < ApplicationController
        skip_forgery_protection if: :should_skip_forgery_protection?

        def index
          locations = proofer.request_facilities('')

          render json: locations.to_json
        end
  
        protected

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
