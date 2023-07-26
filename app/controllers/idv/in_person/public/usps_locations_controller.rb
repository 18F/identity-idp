module Idv
  module InPerson
    module Public
      class UspsLocationsController < ApplicationController
        skip_forgery_protection if: :should_skip_forgery_protection?

        def index
          candidate = UspsInPersonProofing::Applicant.new(
            address: search_params['street_address'],
            city: search_params['city'], state: search_params['state'],
            zip_code: search_params['zip_code']
          )
          locations = proofer.request_facilities(candidate)

          render json: locations.to_json
        end

        protected

        def proofer
          UspsInPersonProofing::Mock::Proofer.new
        end

        def should_skip_forgery_protection?
          IdentityConfig.store.in_person_enable_public_address_search
        end

        def search_params
          params.require(:address).permit(
            :street_address,
            :city,
            :state,
            :zip_code,
          )
        end
      end
    end
  end
end
