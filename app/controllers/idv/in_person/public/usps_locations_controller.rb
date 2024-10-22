# frozen_string_literal: true

module Idv
  module InPerson
    module Public
      class UspsLocationsController < ApplicationController
        skip_forgery_protection

        def index
          candidate = UspsInPersonProofing::Applicant.new(
            address: search_params['street_address'],
            city: search_params['city'], state: search_params['state'],
            zip_code: search_params['zip_code']
          )
          locations = proofer.request_facilities(candidate, false)

          render json: localized_locations(locations).to_json
        end

        def options
          head :ok
        end

        private

        def proofer
          @proofer ||= UspsInPersonProofing::EnrollmentHelper.usps_proofer
        end

        def localized_locations(locations)
          return nil if locations.nil?
          locations.map do |location|
            UspsInPersonProofing::EnrollmentHelper.localized_location(location)
          end
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
