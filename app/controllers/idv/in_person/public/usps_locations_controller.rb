module Idv
  module InPerson
    module Public
      class UspsLocationsController < ApplicationController
        include RenderConditionConcern

        check_or_render_not_found -> { enabled? }

        skip_forgery_protection

        def index
          candidate = UspsInPersonProofing::Applicant.new(
            address: search_params['street_address'],
            city: search_params['city'], state: search_params['state'],
            zip_code: search_params['zip_code']
          )
          locations = proofer.request_facilities(candidate)

          render json: locations.to_json
        end

        def options
          head :ok
        end

        protected

        def proofer
          UspsInPersonProofing::Mock::Proofer.new
        end

        def enabled?
          IdentityConfig.store.in_person_public_address_search_enabled
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
